module app_db
  use iso_c_binding
  use sqlite_bind
  use chelpers_bind
  implicit none

  type(c_ptr) :: db_handle = c_null_ptr
  character(len=256) :: jwt_secret = 'change-me-in-production'

contains

  subroutine db_init()
    character(len=256) :: db_path
    character(len=256) :: secret_env
    integer(c_int) :: rc

    call get_environment_variable('DB_DATABASE', db_path)
    if (len_trim(db_path) == 0) db_path = 'database/database.sqlite'
    call get_environment_variable('JWT_SECRET', secret_env)
    if (len_trim(secret_env) > 0) jwt_secret = trim(secret_env)

    rc = sqlite3_open(to_c_string(trim(db_path)), db_handle)
    if (rc /= SQLITE_OK) stop 'failed to open database'

    call db_exec('PRAGMA journal_mode=WAL')
    call db_exec('PRAGMA busy_timeout=5000')

    call db_exec('CREATE TABLE IF NOT EXISTS users (' // &
      'id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL UNIQUE, password TEXT NOT NULL)')
    call db_exec('CREATE TABLE IF NOT EXISTS categories (' // &
      'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, description TEXT)')
    call db_exec('CREATE TABLE IF NOT EXISTS items (' // &
      'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, ' // &
      'price TEXT NOT NULL, category_id INTEGER, ' // &
      'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL)')
  end subroutine db_init

  subroutine db_exec(sql)
    character(len=*), intent(in) :: sql
    type(c_ptr) :: errmsg
    integer(c_int) :: rc

    rc = sqlite3_exec(db_handle, to_c_string(sql), c_null_ptr, c_null_ptr, errmsg)
    if (rc /= SQLITE_OK) then
      print *, 'SQL error:', trim(sql)
    end if
  end subroutine db_exec

  function db_prepare(sql, stmt) result(rc)
    character(len=*), intent(in) :: sql
    type(c_ptr), intent(out) :: stmt
    integer(c_int) :: rc
    type(c_ptr) :: tail

    rc = sqlite3_prepare_v2(db_handle, to_c_string(sql), -1, stmt, tail)
  end function db_prepare

  function db_scalar_int(sql) result(value)
    character(len=*), intent(in) :: sql
    integer :: value
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    value = 0
    rc = db_prepare(sql, stmt)
    if (rc /= SQLITE_OK) return
    if (sqlite3_step(stmt) == SQLITE_ROW) value = sqlite3_column_int(stmt, 0)
    rc = sqlite3_finalize(stmt)
  end function db_scalar_int

  function user_exists(email) result(found)
    character(len=*), intent(in) :: email
    logical :: found
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    found = .false.
    rc = db_prepare('SELECT 1 FROM users WHERE email = ? LIMIT 1', stmt)
    if (rc /= SQLITE_OK) return
    rc = bind_text(stmt, 1, trim(email))
    if (sqlite3_step(stmt) == SQLITE_ROW) found = .true.
    rc = sqlite3_finalize(stmt)
  end function user_exists

  function user_create(email, password, user_id) result(ok)
    character(len=*), intent(in) :: email
    character(len=*), intent(in) :: password
    integer, intent(out) :: user_id
    logical :: ok
    character(kind=c_char, len=256), target :: hash_buf
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    ok = .false.
    user_id = 0
    if (user_exists(email)) return

    if (chelpers_hash_password(to_c_string(trim(password)), hash_buf, 256) == 0) return

    rc = db_prepare('INSERT INTO users (email, password) VALUES (?, ?)', stmt)
    if (rc /= SQLITE_OK) return
    rc = bind_text(stmt, 1, trim(email))
    rc = bind_text(stmt, 2, from_c_string(c_loc(hash_buf), 256))
    if (sqlite3_step(stmt) /= SQLITE_DONE) then
      rc = sqlite3_finalize(stmt)
      return
    end if
    rc = sqlite3_finalize(stmt)
    user_id = int(sqlite3_last_insert_rowid(db_handle))
    ok = .true.
  end function user_create

  function user_authenticate(email, password, user_id) result(ok)
    character(len=*), intent(in) :: email
    character(len=*), intent(in) :: password
    integer, intent(out) :: user_id
    logical :: ok
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    character(len=256) :: stored_hash

    ok = .false.
    user_id = 0
    rc = db_prepare('SELECT id, password FROM users WHERE email = ?', stmt)
    if (rc /= SQLITE_OK) return
    rc = bind_text(stmt, 1, trim(email))
    if (sqlite3_step(stmt) /= SQLITE_ROW) then
      rc = sqlite3_finalize(stmt)
      return
    end if
    user_id = sqlite3_column_int(stmt, 0)
    stored_hash = from_c_string(sqlite3_column_text(stmt, 1), 256)
    rc = sqlite3_finalize(stmt)
    if (chelpers_verify_password(to_c_string(trim(password)), to_c_string(trim(stored_hash))) == 1) ok = .true.
  end function user_authenticate

  function user_get_by_email(email, user_id) result(found)
    character(len=*), intent(in) :: email
    integer, intent(out) :: user_id
    logical :: found
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    found = .false.
    user_id = 0
    rc = db_prepare('SELECT id FROM users WHERE email = ?', stmt)
    if (rc /= SQLITE_OK) return
    rc = bind_text(stmt, 1, trim(email))
    if (sqlite3_step(stmt) /= SQLITE_ROW) then
      rc = sqlite3_finalize(stmt)
      return
    end if
    user_id = sqlite3_column_int(stmt, 0)
    found = .true.
    rc = sqlite3_finalize(stmt)
  end function user_get_by_email

  function user_get_by_id(user_id, email) result(found)
    integer, intent(in) :: user_id
    character(len=*), intent(out) :: email
    logical :: found
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    found = .false.
    email = ''
    rc = db_prepare('SELECT email FROM users WHERE id = ?', stmt)
    if (rc /= SQLITE_OK) return
    rc = sqlite3_bind_int(stmt, 1, int(user_id, c_int))
    if (sqlite3_step(stmt) /= SQLITE_ROW) then
      rc = sqlite3_finalize(stmt)
      return
    end if
    email = trim(from_c_string(sqlite3_column_text(stmt, 0), 255))
    rc = sqlite3_finalize(stmt)
    found = .true.
  end function user_get_by_id

  function category_name_exists(name, exclude_id) result(found)
    character(len=*), intent(in) :: name
    integer, intent(in), optional :: exclude_id
    logical :: found
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    found = .false.
    if (present(exclude_id)) then
      rc = db_prepare('SELECT 1 FROM categories WHERE name = ? AND id != ? LIMIT 1', stmt)
      if (rc /= SQLITE_OK) return
      rc = bind_text(stmt, 1, trim(name))
      rc = sqlite3_bind_int(stmt, 2, int(exclude_id, c_int))
    else
      rc = db_prepare('SELECT 1 FROM categories WHERE name = ? LIMIT 1', stmt)
      if (rc /= SQLITE_OK) return
      rc = bind_text(stmt, 1, trim(name))
    end if
    if (sqlite3_step(stmt) == SQLITE_ROW) found = .true.
    rc = sqlite3_finalize(stmt)
  end function category_name_exists

  function category_get_by_id(category_id, name, description, found) result(ok)
    integer, intent(in) :: category_id
    character(len=*), intent(out) :: name
    character(len=*), intent(out) :: description
    logical, intent(out) :: found
    logical :: ok
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    ok = .false.
    found = .false.
    name = ''
    description = ''
    rc = db_prepare('SELECT name, description FROM categories WHERE id = ?', stmt)
    if (rc /= SQLITE_OK) return
    rc = sqlite3_bind_int(stmt, 1, int(category_id, c_int))
    if (sqlite3_step(stmt) /= SQLITE_ROW) then
      rc = sqlite3_finalize(stmt)
      ok = .true.
      return
    end if
    name = trim(from_c_string(sqlite3_column_text(stmt, 0), 255))
    description = trim(from_c_string(sqlite3_column_text(stmt, 1), 1024))
    found = .true.
    ok = .true.
    rc = sqlite3_finalize(stmt)
  end function category_get_by_id

  function category_create(name, description, category_id) result(status_code)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: description
    integer, intent(out) :: category_id
    integer :: status_code
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    status_code = 201
    category_id = 0
    if (category_name_exists(name)) then
      status_code = 409
      return
    end if

    rc = db_prepare('INSERT INTO categories (name, description) VALUES (?, ?)', stmt)
    if (rc /= SQLITE_OK) then
      status_code = 500
      return
    end if
    rc = bind_text(stmt, 1, trim(name))
    if (len_trim(description) == 0) then
      rc = sqlite3_bind_null(stmt, 2)
    else
      rc = bind_text(stmt, 2, trim(description))
    end if
    if (sqlite3_step(stmt) /= SQLITE_DONE) then
      status_code = 500
      rc = sqlite3_finalize(stmt)
      return
    end if
    rc = sqlite3_finalize(stmt)
    category_id = int(sqlite3_last_insert_rowid(db_handle))
  end function category_create

  function category_update(category_id, name, description, has_name, has_description) result(status_code)
    integer, intent(in) :: category_id
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: description
    logical, intent(in) :: has_name, has_description
    integer :: status_code
    character(len=256) :: current_name
    character(len=1024) :: current_description
    logical :: found
    type(c_ptr) :: stmt
    integer(c_int) :: rc

    status_code = 200
    if (.not. category_get_by_id(category_id, current_name, current_description, found)) then
      status_code = 500
      return
    end if
    if (.not. found) then
      status_code = 404
      return
    end if

    if (has_name) then
      if (category_name_exists(name, category_id)) then
        status_code = 409
        return
      end if
      current_name = trim(name)
    end if
    if (has_description) current_description = trim(description)

    rc = db_prepare('UPDATE categories SET name = ?, description = ? WHERE id = ?', stmt)
    if (rc /= SQLITE_OK) then
      status_code = 500
      return
    end if
    rc = bind_text(stmt, 1, trim(current_name))
    if (len_trim(current_description) == 0) then
      rc = sqlite3_bind_null(stmt, 2)
    else
      rc = bind_text(stmt, 2, trim(current_description))
    end if
    rc = sqlite3_bind_int(stmt, 3, int(category_id, c_int))
    rc = sqlite3_step(stmt)
    rc = sqlite3_finalize(stmt)
  end function category_update

  function category_delete(category_id) result(status_code)
    integer, intent(in) :: category_id
    integer :: status_code
    character(len=256) :: current_name
    character(len=1024) :: current_description
    logical :: found

    status_code = 204
    if (.not. category_get_by_id(category_id, current_name, current_description, found)) then
      status_code = 500
      return
    end if
    if (.not. found) then
      status_code = 404
      return
    end if
    if (db_scalar_int('SELECT COUNT(*) FROM items WHERE category_id = ' // trim(adjustl(write_int(category_id)))) > 0) then
      status_code = 409
      return
    end if
    call db_exec('DELETE FROM categories WHERE id = ' // trim(adjustl(write_int(category_id))))
  end function category_delete

  function category_list_json(skip, limit) result(json)
    integer, intent(in) :: skip, limit
    character(len=:), allocatable :: json
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    integer :: total, id
    character(len=256) :: name
    character(len=1024) :: description
    character(len=:), allocatable :: items_json

    total = db_scalar_int('SELECT COUNT(*) FROM categories')
    items_json = ''
    rc = db_prepare('SELECT id, name, description FROM categories ORDER BY id LIMIT ? OFFSET ?', stmt)
    if (rc == SQLITE_OK) then
      rc = sqlite3_bind_int(stmt, 1, int(limit, c_int))
      rc = sqlite3_bind_int(stmt, 2, int(skip, c_int))
      do while (sqlite3_step(stmt) == SQLITE_ROW)
        id = sqlite3_column_int(stmt, 0)
        name = trim(from_c_string(sqlite3_column_text(stmt, 1), 255))
        description = trim(from_c_string(sqlite3_column_text(stmt, 2), 1024))
        if (len_trim(items_json) > 0) items_json = trim(items_json) // ','
        items_json = trim(items_json) // category_json(id, name, description)
      end do
      rc = sqlite3_finalize(stmt)
    end if
    json = '{"items":[' // trim(items_json) // '],"total":' // write_int(total) &
      // ',"skip":' // write_int(skip) // ',"limit":' // write_int(limit) // '}'
  end function category_list_json

  function category_json(id, name, description) result(json)
    use json_util
    integer, intent(in) :: id
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: description
    character(len=:), allocatable :: json

    json = '{"id":' // write_int(id) // ',"name":"' // json_escape(trim(name)) // '","description":' &
      // json_string_or_null(trim(description)) // '}'
  end function category_json

  function item_get_by_id(item_id, status_code) result(json)
    use json_util
    integer, intent(in) :: item_id
    integer, intent(out) :: status_code
    character(len=:), allocatable :: json
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    integer :: id, cat_id
    character(len=256) :: name
    character(len=1024) :: description
    character(len=64) :: price
    character(len=256) :: cat_name
    character(len=1024) :: cat_description

    status_code = 200
    json = ''
    rc = db_prepare('SELECT i.id, i.name, i.description, i.price, i.category_id, c.name, c.description ' // &
      'FROM items i LEFT JOIN categories c ON c.id = i.category_id WHERE i.id = ?', stmt)
    if (rc /= SQLITE_OK) then
      status_code = 500
      return
    end if
    rc = sqlite3_bind_int(stmt, 1, int(item_id, c_int))
    if (sqlite3_step(stmt) /= SQLITE_ROW) then
      status_code = 404
      rc = sqlite3_finalize(stmt)
      return
    end if
    id = sqlite3_column_int(stmt, 0)
    name = trim(from_c_string(sqlite3_column_text(stmt, 1), 255))
    description = trim(from_c_string(sqlite3_column_text(stmt, 2), 1024))
    price = trim(from_c_string(sqlite3_column_text(stmt, 3), 64))
    if (sqlite3_column_type(stmt, 4) == 5) then
      cat_id = 0
    else
      cat_id = sqlite3_column_int(stmt, 4)
    end if
    if (cat_id > 0) then
      cat_name = trim(from_c_string(sqlite3_column_text(stmt, 5), 255))
      cat_description = trim(from_c_string(sqlite3_column_text(stmt, 6), 1024))
      json = item_json(id, name, description, price, cat_id, cat_name, cat_description)
    else
      json = item_json(id, name, description, price, 0, '', '')
    end if
    rc = sqlite3_finalize(stmt)
  end function item_get_by_id

  function item_create(name, description, price, category_id, status_code) result(json)
    use json_util
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: description
    real, intent(in) :: price
    integer, intent(in) :: category_id
    integer, intent(out) :: status_code
    character(len=:), allocatable :: json
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    character(len=64) :: price_text
    integer :: new_id
    logical :: found
    character(len=256) :: cat_name
    character(len=1024) :: cat_description

    status_code = 201
    if (category_id > 0) then
      if (.not. category_get_by_id(category_id, cat_name, cat_description, found)) then
        status_code = 500
        return
      end if
      if (.not. found) then
        status_code = 404
        return
      end if
    end if

    rc = db_prepare('INSERT INTO items (name, description, price, category_id) VALUES (?, ?, ?, ?)', stmt)
    if (rc /= SQLITE_OK) then
      status_code = 500
      return
    end if

    rc = bind_text(stmt, 1, trim(name))
    if (len_trim(description) == 0) then
      rc = sqlite3_bind_null(stmt, 2)
    else
      rc = bind_text(stmt, 2, trim(description))
    end if
    write (price_text, '(F0.2)') price
    rc = bind_text(stmt, 3, trim(adjustl(price_text)))
    if (category_id > 0) then
      rc = sqlite3_bind_int(stmt, 4, int(category_id, c_int))
    else
      rc = sqlite3_bind_null(stmt, 4)
    end if
    if (sqlite3_step(stmt) /= SQLITE_DONE) then
      status_code = 500
      rc = sqlite3_finalize(stmt)
      return
    end if
    rc = sqlite3_finalize(stmt)
    new_id = int(sqlite3_last_insert_rowid(db_handle))
    json = item_get_by_id(new_id, status_code)
    status_code = 201
  end function item_create

  function item_update(item_id, name, description, price, category_id, &
      has_name, has_description, has_price, has_category, set_category_null, status_code) result(json)
    use json_util
    use json_parse
    integer, intent(in) :: item_id, category_id
    character(len=*), intent(in) :: name, description
    real, intent(in) :: price
    logical, intent(in) :: has_name, has_description, has_price, has_category, set_category_null
    integer, intent(out) :: status_code
    character(len=:), allocatable :: json
    character(len=:), allocatable :: current_json
    character(len=256) :: new_name, cat_name
    character(len=1024) :: new_description, cat_desc
    character(len=64) :: new_price_text
    integer :: new_cat_id
    real :: new_price
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    logical :: found

    status_code = 200
    current_json = item_get_by_id(item_id, status_code)
    if (status_code == 404) return

    new_name = name
    new_description = description
    new_price = price
    new_cat_id = category_id

    if (.not. has_name) new_name = json_get_string(current_json, 'name')
    if (.not. has_description) new_description = json_get_string(current_json, 'description')
    if (.not. has_price) new_price = json_get_number(current_json, 'price')
    if (.not. has_category) then
      if (index(current_json, '"category_id":null') > 0) then
        new_cat_id = 0
      else
        new_cat_id = nint(json_get_number(current_json, 'category_id'))
      end if
    else if (set_category_null) then
      new_cat_id = 0
    end if

    if (has_category .and. .not. set_category_null .and. new_cat_id > 0) then
      if (.not. category_get_by_id(new_cat_id, cat_name, cat_desc, found)) then
        status_code = 500
        return
      end if
      if (.not. found) then
        status_code = 404
        return
      end if
    end if

    rc = db_prepare('UPDATE items SET name = ?, description = ?, price = ?, category_id = ? WHERE id = ?', stmt)
    if (rc /= SQLITE_OK) then
      status_code = 500
      return
    end if
    rc = bind_text(stmt, 1, trim(new_name))
    if (len_trim(new_description) == 0) then
      rc = sqlite3_bind_null(stmt, 2)
    else
      rc = bind_text(stmt, 2, trim(new_description))
    end if
    write (new_price_text, '(F0.2)') new_price
    rc = bind_text(stmt, 3, trim(adjustl(new_price_text)))
    if (new_cat_id > 0) then
      rc = sqlite3_bind_int(stmt, 4, int(new_cat_id, c_int))
    else
      rc = sqlite3_bind_null(stmt, 4)
    end if
    rc = sqlite3_bind_int(stmt, 5, int(item_id, c_int))
    if (sqlite3_step(stmt) /= SQLITE_DONE) then
      status_code = 500
      rc = sqlite3_finalize(stmt)
      return
    end if
    rc = sqlite3_finalize(stmt)
    json = item_get_by_id(item_id, status_code)
  end function item_update

  function item_delete(item_id) result(status_code)
    integer, intent(in) :: item_id
    integer :: status_code
    character(len=:), allocatable :: dummy

    dummy = item_get_by_id(item_id, status_code)
    if (status_code == 404) return
    call db_exec('DELETE FROM items WHERE id = ' // trim(adjustl(write_int(item_id))))
    status_code = 204
  end function item_delete

  function item_list_json(skip, limit, min_price, max_price, category_id, name_contains, &
      has_min, has_max, has_cat, has_name) result(json)
    use json_util
    integer, intent(in) :: skip, limit
    real, intent(in) :: min_price, max_price
    integer, intent(in) :: category_id
    character(len=*), intent(in) :: name_contains
    logical, intent(in) :: has_min, has_max, has_cat, has_name
    character(len=:), allocatable :: json
    character(len=:), allocatable :: where_clause, items_json
    character(len=64) :: min_text, max_text
    integer :: total, id, cat_id
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    character(len=256) :: name, cat_name
    character(len=1024) :: description, cat_description
    character(len=64) :: price

    where_clause = ''
    if (has_min) then
      write (min_text, '(F0.6)') min_price
      where_clause = trim(where_clause) // ' AND CAST(i.price AS REAL) >= ' // trim(adjustl(min_text))
    end if
    if (has_max) then
      write (max_text, '(F0.6)') max_price
      where_clause = trim(where_clause) // ' AND CAST(i.price AS REAL) <= ' // trim(adjustl(max_text))
    end if
    if (has_cat) where_clause = trim(where_clause) // ' AND i.category_id = ' // write_int(category_id)
    if (has_name) where_clause = trim(where_clause) // ' AND LOWER(i.name) LIKE ''%' // &
      trim(lower(name_contains)) // '%'''

    total = db_scalar_int('SELECT COUNT(*) FROM items i WHERE 1=1' // trim(where_clause))
    items_json = ''
    rc = db_prepare('SELECT i.id, i.name, i.description, i.price, i.category_id, c.name, c.description ' // &
      'FROM items i LEFT JOIN categories c ON c.id = i.category_id WHERE 1=1' // trim(where_clause) // &
      ' ORDER BY i.id LIMIT ' // write_int(limit) // ' OFFSET ' // write_int(skip), stmt)
    if (rc == SQLITE_OK) then
      do while (sqlite3_step(stmt) == SQLITE_ROW)
        id = sqlite3_column_int(stmt, 0)
        name = trim(from_c_string(sqlite3_column_text(stmt, 1), 255))
        description = trim(from_c_string(sqlite3_column_text(stmt, 2), 1024))
        price = trim(from_c_string(sqlite3_column_text(stmt, 3), 64))
        if (sqlite3_column_type(stmt, 4) == 5) then
          cat_id = 0
        else
          cat_id = sqlite3_column_int(stmt, 4)
        end if
        if (len_trim(items_json) > 0) items_json = trim(items_json) // ','
        if (cat_id > 0) then
          cat_name = trim(from_c_string(sqlite3_column_text(stmt, 5), 255))
          cat_description = trim(from_c_string(sqlite3_column_text(stmt, 6), 1024))
          items_json = trim(items_json) // item_json(id, name, description, price, cat_id, cat_name, cat_description)
        else
          items_json = trim(items_json) // item_json(id, name, description, price, 0, '', '')
        end if
      end do
      rc = sqlite3_finalize(stmt)
    end if
    json = '{"items":[' // trim(items_json) // '],"total":' // write_int(total) &
      // ',"skip":' // write_int(skip) // ',"limit":' // write_int(limit) // '}'
  end function item_list_json

  function item_stats_json() result(json)
    integer :: total, uncategorized
    real :: avg_price, min_price, max_price
    character(len=:), allocatable :: json

    total = db_scalar_int('SELECT COUNT(*) FROM items')
    if (total == 0) then
      json = '{"total_items":0,"average_price":0.0,"min_price":null,"max_price":null,' // &
        '"uncategorized_count":0,"by_category":[]}'
      return
    end if

    avg_price = db_scalar_real('SELECT AVG(CAST(price AS REAL)) FROM items')
    min_price = db_scalar_real('SELECT MIN(CAST(price AS REAL)) FROM items')
    max_price = db_scalar_real('SELECT MAX(CAST(price AS REAL)) FROM items')
    uncategorized = db_scalar_int('SELECT COUNT(*) FROM items WHERE category_id IS NULL')

    json = '{"total_items":' // write_int(total) &
      // ',"average_price":' // write_real(round2(avg_price)) &
      // ',"min_price":' // write_real(round2(min_price)) &
      // ',"max_price":' // write_real(round2(max_price)) &
      // ',"uncategorized_count":' // write_int(uncategorized) &
      // ',"by_category":' // item_stats_by_category() // '}'
  end function item_stats_json

  function item_stats_by_category() result(json)
    character(len=:), allocatable :: json
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    integer :: cat_id, item_count
    character(len=256) :: cat_name
    real :: avg_price

    json = '['
    rc = db_prepare('SELECT categories.id, categories.name, COUNT(items.id), AVG(CAST(items.price AS REAL)) ' // &
      'FROM items INNER JOIN categories ON categories.id = items.category_id ' // &
      'GROUP BY categories.id, categories.name ORDER BY categories.name', stmt)
    if (rc == SQLITE_OK) then
      do while (sqlite3_step(stmt) == SQLITE_ROW)
        cat_id = sqlite3_column_int(stmt, 0)
        cat_name = trim(from_c_string(sqlite3_column_text(stmt, 1), 255))
        item_count = sqlite3_column_int(stmt, 2)
        call read_real_from_text(from_c_string(sqlite3_column_text(stmt, 3), 64), avg_price)
        if (len_trim(json) > 1) json = trim(json) // ','
        json = trim(json) // '{"category_id":' // write_int(cat_id) &
          // ',"category_name":"' // trim(cat_name) // '","item_count":' // write_int(item_count) &
          // ',"average_price":' // write_real(round2(avg_price)) // '}'
      end do
      rc = sqlite3_finalize(stmt)
    end if
    json = trim(json) // ']'
  end function item_stats_by_category

  function item_json(id, name, description, price, cat_id, cat_name, cat_description) result(json)
    use json_util
    integer, intent(in) :: id, cat_id
    character(len=*), intent(in) :: name, description, price, cat_name, cat_description
    character(len=:), allocatable :: json
    real :: price_num

    read (price, *) price_num
    json = '{"id":' // write_int(id) // ',"name":"' // json_escape(trim(name)) // '","description":' &
      // json_string_or_null(trim(description)) // ',"price":' // write_real(price_num) // ',"category_id":'
    if (cat_id > 0) then
      json = trim(json) // write_int(cat_id) // ',"category":' // &
        category_json(cat_id, cat_name, cat_description) // '}'
    else
      json = trim(json) // 'null,"category":null}'
    end if
  end function item_json

  function jwt_create_token(email) result(token)
    character(len=*), intent(in) :: email
    character(len=2048) :: token
    character(kind=c_char, len=2048), target :: token_c

    if (chelpers_jwt_create(to_c_string(trim(email)), &
        to_c_string(trim(jwt_secret)), token_c, 2048) == 1) then
      token = from_c_string(c_loc(token_c), 2048)
    else
      token = ''
    end if
  end function jwt_create_token

  function jwt_verify_token(token, email) result(ok)
    character(len=*), intent(in) :: token
    character(len=*), intent(out) :: email
    logical :: ok
    character(kind=c_char, len=256), target :: email_c

    ok = .false.
    email = ''
    if (chelpers_jwt_verify(to_c_string(trim(token)), to_c_string(trim(jwt_secret)), &
        email_c, 256) == 1) then
      email = from_c_string(c_loc(email_c), 255)
      ok = .true.
    end if
  end function jwt_verify_token

  function write_int(value) result(text)
    integer, intent(in) :: value
    character(len=:), allocatable :: text
    character(len=32) :: buffer

    write (buffer, '(I0)') value
    text = trim(adjustl(buffer))
  end function write_int

  function write_real(value) result(text)
    real, intent(in) :: value
    character(len=:), allocatable :: text
    character(len=64) :: buffer

    write (buffer, '(F0.2)') value
    text = trim(adjustl(buffer))
  end function write_real

  function round2(value) result(out)
    real, intent(in) :: value
    real :: out
    out = nint(value * 100.0) / 100.0
  end function round2

  function db_scalar_real(sql) result(value)
    character(len=*), intent(in) :: sql
    real :: value
    type(c_ptr) :: stmt
    integer(c_int) :: rc
    character(len=64) :: text

    value = 0.0
    rc = db_prepare(sql, stmt)
    if (rc /= SQLITE_OK) return
    if (sqlite3_step(stmt) == SQLITE_ROW) then
      text = trim(from_c_string(sqlite3_column_text(stmt, 0), 64))
      read (text, *) value
    end if
    rc = sqlite3_finalize(stmt)
  end function db_scalar_real

  subroutine read_real_from_text(text, value)
    character(len=*), intent(in) :: text
    real, intent(out) :: value
    read (text, *) value
  end subroutine read_real_from_text

  function lower(text) result(out)
    character(len=*), intent(in) :: text
    character(len=len(text)) :: out
    integer :: i
    out = text
    do i = 1, len_trim(out)
      if (ichar(out(i:i)) >= ichar('A') .and. ichar(out(i:i)) <= ichar('Z')) then
        out(i:i) = char(ichar(out(i:i)) + 32)
      end if
    end do
    out = trim(out)
  end function lower

end module app_db
