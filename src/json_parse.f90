module json_parse
  implicit none

contains

  function json_get_string(body, key) result(value)
    character(len=*), intent(in) :: body
    character(len=*), intent(in) :: key
    character(len=:), allocatable :: value
    character(len=:), allocatable :: pattern
    integer :: start_pos, end_pos

    value = ''
    pattern = '"' // trim(key) // '":"'
    start_pos = index(body, pattern)
    if (start_pos == 0) return
    start_pos = start_pos + len(pattern)
    end_pos = index(body(start_pos:), '"')
    if (end_pos == 0) return
    value = body(start_pos:start_pos + end_pos - 2)
  end function json_get_string

  function json_has_key(body, key) result(found)
    character(len=*), intent(in) :: body
    character(len=*), intent(in) :: key
    logical :: found
    character(len=:), allocatable :: pattern

    pattern = '"' // trim(key) // '"'
    found = index(body, pattern) > 0
  end function json_has_key

  function json_get_number(body, key) result(value)
    character(len=*), intent(in) :: body
    character(len=*), intent(in) :: key
    real :: value
    character(len=:), allocatable :: pattern
    integer :: start_pos, i
    character(len=64) :: chunk

    value = 0.0
    pattern = '"' // trim(key) // '":'
    start_pos = index(body, pattern)
    if (start_pos == 0) return
    start_pos = start_pos + len(pattern)
    chunk = adjustl(body(start_pos:))
    if (chunk(1:4) == 'null') return
    do i = 1, min(63, len_trim(chunk))
      if (chunk(i:i) == ',' .or. chunk(i:i) == '}' .or. chunk(i:i) == ']') exit
    end do
    read (chunk(1:i - 1), *) value
  end function json_get_number

  function json_get_nullable_string(body, key, present) result(value)
    character(len=*), intent(in) :: body
    character(len=*), intent(in) :: key
    logical, intent(out) :: present
    character(len=:), allocatable :: value
    character(len=:), allocatable :: pattern
    integer :: start_pos

    present = .false.
    value = ''
    pattern = '"' // trim(key) // '":'
    start_pos = index(body, pattern)
    if (start_pos == 0) return
    present = .true.
    start_pos = start_pos + len(pattern)
    if (index(adjustl(body(start_pos:)), 'null') == 1) then
      value = ''
      return
    end if
    value = json_get_string(body, key)
  end function json_get_nullable_string

  function query_get_string(query, key) result(value)
    character(len=*), intent(in) :: query
    character(len=*), intent(in) :: key
    character(len=:), allocatable :: value
    character(len=:), allocatable :: pattern
    integer :: start_pos, end_pos

    value = ''
    if (len_trim(query) == 0) return
    pattern = trim(key) // '='
    start_pos = index(query, pattern)
    if (start_pos == 0) return
    start_pos = start_pos + len(pattern)
    end_pos = index(query(start_pos:), '&')
    if (end_pos == 0) then
      value = query(start_pos:)
    else
      value = query(start_pos:start_pos + end_pos - 2)
    end if
  end function query_get_string

  function query_get_int(query, key, found) result(value)
    character(len=*), intent(in) :: query
    character(len=*), intent(in) :: key
    logical, intent(out) :: found
    integer :: value
    character(len=:), allocatable :: text

    found = .false.
    value = 0
    text = query_get_string(query, key)
    if (len_trim(text) == 0) return
    found = .true.
    read (text, *) value
  end function query_get_int

  function query_get_real(query, key, found) result(value)
    character(len=*), intent(in) :: query
    character(len=*), intent(in) :: key
    logical, intent(out) :: found
    real :: value
    character(len=:), allocatable :: text

    found = .false.
    value = 0.0
    text = query_get_string(query, key)
    if (len_trim(text) == 0) return
    found = .true.
    read (text, *) value
  end function query_get_real

  function parse_form_field(body, key) result(value)
    character(len=*), intent(in) :: body
    character(len=*), intent(in) :: key
    character(len=:), allocatable :: value
    character(len=:), allocatable :: pattern
    integer :: start_pos, end_pos

    value = ''
    pattern = trim(key) // '='
    start_pos = index(body, pattern)
    if (start_pos == 0) return
    start_pos = start_pos + len(pattern)
    end_pos = index(body(start_pos:), '&')
    if (end_pos == 0) then
      value = body(start_pos:)
    else
      value = body(start_pos:start_pos + end_pos - 2)
    end if
  end function parse_form_field

end module json_parse
