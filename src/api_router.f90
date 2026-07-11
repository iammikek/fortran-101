module api_router
  use http_types
  use json_util
  use json_parse
  use app_db
  implicit none

contains

  subroutine route_request(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    character(len=2048) :: path
    integer :: user_id

    resp%status = 200
    resp%content_type = 'application/json'
    resp%body = ''

    path = trim(req%path)

    if (trim(req%method) == 'GET' .and. path == '/') then
      resp%body = '{"message":"Hello from fortran-101"}'
      return
    end if

    if (trim(req%method) == 'GET' .and. path == '/health') then
      resp%body = '{"status":"ok","database":"connected"}'
      return
    end if

    if (trim(req%method) == 'POST' .and. path == '/auth/register') then
      call handle_register(req, resp)
      return
    end if

    if (trim(req%method) == 'POST' .and. path == '/auth/login') then
      call handle_login(req, resp)
      return
    end if

    if (trim(req%method) == 'GET' .and. path == '/auth/me') then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_me(user_id, resp)
      return
    end if

    if (trim(req%method) == 'GET' .and. path == '/items/stats/summary') then
      resp%body = item_stats_json()
      return
    end if

    if (trim(req%method) == 'GET' .and. path == '/items') then
      call handle_items_index(req, resp)
      return
    end if

    if (trim(req%method) == 'GET' .and. index(path, '/items/') == 1) then
      call handle_item_show(path, resp)
      return
    end if

    if (trim(req%method) == 'POST' .and. path == '/items') then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_item_create(req, resp)
      return
    end if

    if (trim(req%method) == 'PATCH' .and. index(path, '/items/') == 1) then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_item_update(path, req, resp)
      return
    end if

    if (trim(req%method) == 'DELETE' .and. index(path, '/items/') == 1) then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_item_delete(path, resp)
      return
    end if

    if (trim(req%method) == 'GET' .and. path == '/categories') then
      call handle_categories_index(req, resp)
      return
    end if

    if (trim(req%method) == 'GET' .and. index(path, '/categories/') == 1) then
      call handle_category_show(path, resp)
      return
    end if

    if (trim(req%method) == 'POST' .and. path == '/categories') then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_category_create(req, resp)
      return
    end if

    if (trim(req%method) == 'PATCH' .and. index(path, '/categories/') == 1) then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_category_update(path, req, resp)
      return
    end if

    if (trim(req%method) == 'DELETE' .and. index(path, '/categories/') == 1) then
      call require_auth(req, resp, user_id)
      if (resp%status /= 200) return
      call handle_category_delete(path, resp)
      return
    end if

    call error_json(resp, 'Not Found', 404, 'NOT_FOUND')
  end subroutine route_request

  subroutine require_auth(req, resp, user_id)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    integer, intent(out) :: user_id
    character(len=2048) :: token
    character(len=256) :: email
    logical :: ok, found

    user_id = 0
    if (len_trim(req%auth_header) < 8 .or. req%auth_header(1:7) /= 'Bearer ') then
      call error_json(resp, 'Not authenticated', 401)
      return
    end if
    token = trim(req%auth_header(8:))
    ok = jwt_verify_token(token, email)
    if (.not. ok) then
      call error_json(resp, 'Could not validate credentials', 401)
      return
    end if
    found = user_get_by_email(email, user_id)
    if (.not. found) then
      call error_json(resp, 'Could not validate credentials', 401)
      return
    end if
    resp%status = 200
  end subroutine require_auth

  subroutine handle_register(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    character(len=:), allocatable :: email, password
    integer :: user_id
    character(len=:), allocatable :: err

    err = validate_register(req%body)
    if (len_trim(err) > 0) then
      call error_json(resp, trim(err), 422)
      return
    end if

    email = json_get_string(req%body, 'email')
    password = json_get_string(req%body, 'password')

    if (user_exists(email)) then
      call error_json(resp, "User email '" // trim(email) // "' already exists", 409, 'USER_EMAIL_EXISTS')
      return
    end if

    if (.not. user_create(email, password, user_id)) then
      call error_json(resp, 'Internal Server Error', 500)
      return
    end if

    resp%status = 201
    resp%body = '{"id":' // write_int(user_id) // ',"email":"' // json_escape(trim(email)) // '"}'
  end subroutine handle_register

  subroutine handle_login(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    character(len=256) :: email, password
    character(len=2048) :: token
    integer :: user_id
    logical :: ok

    if (index(req%content_type, 'json') > 0) then
      email = json_get_string(req%body, 'username')
      if (len_trim(email) == 0) email = json_get_string(req%body, 'email')
      password = json_get_string(req%body, 'password')
    else
      email = parse_form_field(req%body, 'username')
      if (len_trim(email) == 0) email = parse_form_field(req%body, 'email')
      password = parse_form_field(req%body, 'password')
    end if

    if (len_trim(email) == 0 .or. len_trim(password) == 0) then
      email = query_get_string(req%query, 'username')
      if (len_trim(email) == 0) email = query_get_string(req%query, 'email')
      password = query_get_string(req%query, 'password')
    end if

    ok = user_authenticate(email, password, user_id)
    if (.not. ok) then
      call error_json(resp, 'Incorrect email or password', 401)
      return
    end if

    token = jwt_create_token(email)
    resp%body = '{"access_token":"' // trim(token) // '","token_type":"bearer"}'
  end subroutine handle_login

  subroutine handle_me(user_id, resp)
    integer, intent(in) :: user_id
    type(http_response), intent(inout) :: resp
    character(len=256) :: email
    logical :: found

    found = user_get_by_id(user_id, email)
    if (.not. found) then
      call error_json(resp, 'Unauthorized', 401)
      return
    end if
    resp%body = '{"id":' // write_int(user_id) // ',"email":"' // json_escape(trim(email)) // '"}'
  end subroutine handle_me

  subroutine handle_categories_index(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    integer :: skip, limit
    logical :: found

    skip = 0
    limit = 10
    skip = query_get_int(req%query, 'skip', found)
    if (.not. found) skip = 0
    limit = query_get_int(req%query, 'limit', found)
    if (.not. found) limit = 10
    skip = max(0, skip)
    limit = min(100, max(1, limit))

    resp%body = category_list_json(skip, limit)
  end subroutine handle_categories_index

  subroutine handle_category_show(path, resp)
    character(len=*), intent(in) :: path
    type(http_response), intent(inout) :: resp
    integer :: category_id
    character(len=256) :: name
    character(len=1024) :: description
    logical :: found, ok

    category_id = parse_path_id(path, '/categories/')
    if (category_id <= 0) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    ok = category_get_by_id(category_id, name, description, found)
    if (.not. ok) then
      call error_json(resp, 'Internal Server Error', 500)
      return
    end if
    if (.not. found) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    resp%body = category_json(category_id, name, description)
  end subroutine handle_category_show

  subroutine handle_category_create(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    character(len=:), allocatable :: name, description
    character(len=:), allocatable :: err
    integer :: category_id, status_code

    err = validate_category_create(req%body)
    if (len_trim(err) > 0) then
      call error_json(resp, trim(err), 422)
      return
    end if

    name = json_get_string(req%body, 'name')
    description = ''
    if (json_has_key(req%body, 'description')) description = json_get_string(req%body, 'description')

    status_code = category_create(name, description, category_id)
    if (status_code == 409) then
      call error_json(resp, "Category name '" // trim(name) // "' already exists", 409, 'CATEGORY_NAME_EXISTS')
      return
    end if
    if (status_code /= 201) then
      call error_json(resp, 'Internal Server Error', 500)
      return
    end if

    resp%status = 201
    resp%body = category_json(category_id, name, description)
  end subroutine handle_category_create

  subroutine handle_category_update(path, req, resp)
    character(len=*), intent(in) :: path
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    integer :: category_id, status_code
    character(len=256) :: name, current_name
    character(len=1024) :: description
    logical :: has_name, has_description, found

    category_id = parse_path_id(path, '/categories/')
    if (category_id <= 0) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    has_name = json_has_key(req%body, 'name')
    has_description = json_has_key(req%body, 'description')
    name = json_get_string(req%body, 'name')
    description = json_get_string(req%body, 'description')

    status_code = category_update(category_id, name, description, has_name, has_description)
    if (status_code == 404) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    if (status_code == 409) then
      call error_json(resp, "Category name '" // trim(name) // "' already exists", 409, 'CATEGORY_NAME_EXISTS')
      return
    end if

    call handle_category_show(path, resp)
  end subroutine handle_category_update

  subroutine handle_category_delete(path, resp)
    character(len=*), intent(in) :: path
    type(http_response), intent(inout) :: resp
    integer :: category_id, status_code

    category_id = parse_path_id(path, '/categories/')
    if (category_id <= 0) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    status_code = category_delete(category_id)
    if (status_code == 404) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    if (status_code == 409) then
      call error_json(resp, 'Category has items and cannot be deleted', 409, 'CATEGORY_IN_USE')
      return
    end if
    resp%status = 204
    resp%body = ''
  end subroutine handle_category_delete

  subroutine handle_items_index(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    integer :: skip, limit, category_id
    real :: min_price, max_price
    logical :: found, has_min, has_max, has_cat, has_name
    character(len=256) :: name_contains
    character(len=:), allocatable :: err

    skip = 0
    limit = 10
    has_min = .false.
    has_max = .false.
    has_cat = .false.
    has_name = .false.
    name_contains = ''

    skip = query_get_int(req%query, 'skip', found)
    if (.not. found) skip = 0
    limit = query_get_int(req%query, 'limit', found)
    if (.not. found) limit = 10

    err = validate_items_list(req%query, skip, limit)
    if (len_trim(err) > 0) then
      call error_json(resp, trim(err), 422)
      return
    end if

    skip = max(0, skip)
    limit = min(100, max(1, limit))

    min_price = query_get_real(req%query, 'min_price', has_min)
    max_price = query_get_real(req%query, 'max_price', has_max)
    category_id = query_get_int(req%query, 'category_id', has_cat)
    name_contains = query_get_string(req%query, 'name_contains')
    has_name = len_trim(name_contains) > 0

    resp%body = item_list_json(skip, limit, min_price, max_price, category_id, name_contains, &
      has_min, has_max, has_cat, has_name)
  end subroutine handle_items_index

  subroutine handle_item_show(path, resp)
    character(len=*), intent(in) :: path
    type(http_response), intent(inout) :: resp
    integer :: item_id, status_code
    character(len=:), allocatable :: json

    item_id = parse_path_id(path, '/items/')
    if (item_id <= 0) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if
    json = item_get_by_id(item_id, status_code)
    if (status_code == 404) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if
    resp%body = json
  end subroutine handle_item_show

  subroutine handle_item_create(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    character(len=:), allocatable :: name, description, err, json
    real :: price
    integer :: category_id, status_code
    logical :: has_cat

    err = validate_item_create(req%body)
    if (len_trim(err) > 0) then
      call error_json(resp, trim(err), 422)
      return
    end if

    name = json_get_string(req%body, 'name')
    description = ''
    if (json_has_key(req%body, 'description')) description = json_get_string(req%body, 'description')
    price = json_get_number(req%body, 'price')
    category_id = 0
    has_cat = json_has_key(req%body, 'category_id')
    if (has_cat) category_id = nint(json_get_number(req%body, 'category_id'))

    json = item_create(name, description, price, category_id, status_code)
    if (status_code == 404) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    if (status_code /= 201) then
      call error_json(resp, 'Internal Server Error', 500)
      return
    end if
    resp%status = 201
    resp%body = json
  end subroutine handle_item_create

  subroutine handle_item_update(path, req, resp)
    character(len=*), intent(in) :: path
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp
    integer :: item_id, status_code, category_id
    character(len=256) :: name, description
    real :: price
    logical :: has_name, has_description, has_price, has_category, set_category_null
    character(len=:), allocatable :: json

    item_id = parse_path_id(path, '/items/')
    if (item_id <= 0) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if
    has_name = json_has_key(req%body, 'name')
    has_description = json_has_key(req%body, 'description')
    has_price = json_has_key(req%body, 'price')
    has_category = json_has_key(req%body, 'category_id')
    set_category_null = .false.
    name = json_get_string(req%body, 'name')
    description = json_get_string(req%body, 'description')
    price = json_get_number(req%body, 'price')
    category_id = 0
    if (has_category) then
      if (index(adjustl(req%body), '"category_id":null') > 0) then
        set_category_null = .true.
      else
        category_id = nint(json_get_number(req%body, 'category_id'))
      end if
    end if

    json = item_get_by_id(item_id, status_code)
    if (status_code == 404) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if

    json = item_update(item_id, name, description, price, category_id, &
      has_name, has_description, has_price, has_category, set_category_null, status_code)
    if (status_code == 404) then
      call error_json(resp, 'Category not found', 404, 'CATEGORY_NOT_FOUND')
      return
    end if
    if (status_code /= 200) then
      call error_json(resp, 'Internal Server Error', 500)
      return
    end if
    resp%body = json
  end subroutine handle_item_update

  subroutine handle_item_delete(path, resp)
    character(len=*), intent(in) :: path
    type(http_response), intent(inout) :: resp
    integer :: item_id, status_code

    item_id = parse_path_id(path, '/items/')
    if (item_id <= 0) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if
    status_code = item_delete(item_id)
    if (status_code == 404) then
      call error_json(resp, 'Item not found', 404, 'ITEM_NOT_FOUND')
      return
    end if
    resp%status = 204
    resp%body = ''
  end subroutine handle_item_delete

  function parse_path_id(path, prefix) result(id)
    character(len=*), intent(in) :: path
    character(len=*), intent(in) :: prefix
    integer :: id, ios, i
    character(len=64) :: chunk

    id = 0
    chunk = trim(path(len(trim(prefix)) + 1:))
    if (len_trim(chunk) == 0) return
    do i = 1, len_trim(chunk)
      if (chunk(i:i) < '0' .or. chunk(i:i) > '9') return
    end do
    read (chunk, *, iostat=ios) id
    if (ios /= 0 .or. id <= 0) id = 0
  end function parse_path_id

  function validate_register(body) result(err)
    character(len=*), intent(in) :: body
    character(len=:), allocatable :: err
    character(len=:), allocatable :: email, password

    err = ''
    email = json_get_string(body, 'email')
    password = json_get_string(body, 'password')

    if (len_trim(email) == 0) err = 'The email field is required.'
    if (len_trim(err) > 0) return
    if (len_trim(password) == 0) err = 'The password field is required.'
    if (len_trim(err) > 0) return
    if (index(email, '@') == 0 .or. index(email(index(email, '@') + 1:), '.') == 0) &
      err = 'The email field must be a valid email address.'
    if (len_trim(err) > 0) return
    if (len_trim(email) < 5) err = 'The email field must be at least 5 characters.'
    if (len_trim(err) > 0) return
    if (len_trim(password) < 8) err = 'The password field must be at least 8 characters.'
  end function validate_register

  function validate_category_create(body) result(err)
    character(len=*), intent(in) :: body
    character(len=:), allocatable :: err
    character(len=:), allocatable :: name

    err = ''
    name = json_get_string(body, 'name')
    if (len_trim(name) == 0) err = 'The name field is required.'
    if (len_trim(err) > 0) return
    if (len_trim(name) > 100) err = 'The name field must not be greater than 100 characters.'
  end function validate_category_create

  function validate_item_create(body) result(err)
    character(len=*), intent(in) :: body
    character(len=:), allocatable :: err
    character(len=:), allocatable :: name
    real :: price

    err = ''
    name = json_get_string(body, 'name')
    if (len_trim(name) == 0) err = 'The name field is required.'
    if (len_trim(err) > 0) return
    price = json_get_number(body, 'price')
    if (.not. json_has_key(body, 'price')) err = 'The price field is required.'
    if (len_trim(err) > 0) return
    if (price <= 0.0) err = 'The price field must be greater than 0.'
  end function validate_item_create

  function validate_items_list(query, skip_val, limit_val) result(err)
    character(len=*), intent(in) :: query
    integer, intent(in) :: skip_val, limit_val
    character(len=:), allocatable :: err
    logical :: found
    integer :: parsed

    err = ''
    parsed = query_get_int(query, 'limit', found)
    if (found .and. (limit_val < 1 .or. limit_val > 100)) err = 'The limit field must not be greater than 100.'
    parsed = query_get_int(query, 'skip', found)
    if (found .and. skip_val < 0) err = 'The skip field must be at least 0.'
    if (len_trim(err) == 0) then
      parsed = query_get_real(query, 'min_price', found)
      if (found .and. parsed <= 0.0) err = 'The min price field must be greater than 0.'
    end if
  end function validate_items_list

end module api_router
