module sqlite_bind
  use iso_c_binding
  use chelpers_bind
  implicit none

  type, bind(c) :: sqlite3
  end type sqlite3

  type, bind(c) :: sqlite3_stmt
  end type sqlite3_stmt

  integer(c_int), parameter :: SQLITE_OK = 0
  integer(c_int), parameter :: SQLITE_ROW = 100
  integer(c_int), parameter :: SQLITE_DONE = 101

  interface
    integer(c_int) function sqlite3_open(filename, pp_db) bind(c, name='sqlite3_open')
      import c_char, c_int, c_ptr
      character(kind=c_char), intent(in) :: filename(*)
      type(c_ptr), intent(out) :: pp_db
    end function sqlite3_open

    integer(c_int) function sqlite3_close(db) bind(c, name='sqlite3_close')
      import c_int, c_ptr
      type(c_ptr), value :: db
    end function sqlite3_close

    integer(c_int) function sqlite3_exec(db, sql, callback, arg, errmsg) bind(c, name='sqlite3_exec')
      import c_char, c_int, c_ptr
      type(c_ptr), value :: db
      character(kind=c_char), intent(in) :: sql(*)
      type(c_ptr), value :: callback, arg
      type(c_ptr), intent(out) :: errmsg
    end function sqlite3_exec

    integer(c_int) function sqlite3_prepare_v2(db, z_sql, n_byte, pp_stmt, pz_tail) bind(c, name='sqlite3_prepare_v2')
      import c_char, c_int, c_ptr
      type(c_ptr), value :: db
      character(kind=c_char), intent(in) :: z_sql(*)
      integer(c_int), value :: n_byte
      type(c_ptr), intent(out) :: pp_stmt
      type(c_ptr), intent(out) :: pz_tail
    end function sqlite3_prepare_v2

    integer(c_int) function sqlite3_step(stmt) bind(c, name='sqlite3_step')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
    end function sqlite3_step

    integer(c_int) function sqlite3_finalize(stmt) bind(c, name='sqlite3_finalize')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
    end function sqlite3_finalize

    integer(c_int) function sqlite3_bind_text(stmt, idx, value, n, destructor) bind(c, name='sqlite3_bind_text')
      import c_char, c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: idx, n
      character(kind=c_char), intent(in) :: value(*)
      type(c_ptr), value :: destructor
    end function sqlite3_bind_text

    integer(c_int) function sqlite3_bind_int(stmt, idx, value) bind(c, name='sqlite3_bind_int')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: idx, value
    end function sqlite3_bind_int

    integer(c_int) function sqlite3_bind_null(stmt, idx) bind(c, name='sqlite3_bind_null')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: idx
    end function sqlite3_bind_null

    type(c_ptr) function sqlite3_column_text(stmt, i_col) bind(c, name='sqlite3_column_text')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: i_col
    end function sqlite3_column_text

    integer(c_int) function sqlite3_column_int(stmt, i_col) bind(c, name='sqlite3_column_int')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: i_col
    end function sqlite3_column_int

    integer(c_int) function sqlite3_column_type(stmt, i_col) bind(c, name='sqlite3_column_type')
      import c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: i_col
    end function sqlite3_column_type

    integer(c_int64_t) function sqlite3_last_insert_rowid(db) bind(c, name='sqlite3_last_insert_rowid')
      import c_int64_t, c_ptr
      type(c_ptr), value :: db
    end function sqlite3_last_insert_rowid
  end interface

contains

  subroutine set_c_string(input_text, cstr, n)
    character(len=*), intent(in) :: input_text
    character(kind=c_char, len=4096), intent(out) :: cstr
    integer, intent(out) :: n
    integer :: i

    n = min(len_trim(input_text), 4095)
    do i = 1, n
      cstr(i:i) = char(ichar(input_text(i:i)), kind=c_char)
    end do
    cstr(n + 1:n + 1) = c_null_char
  end subroutine set_c_string

  function bind_text(stmt, idx, input_text) result(rc)
    type(c_ptr), intent(in) :: stmt
    integer, intent(in) :: idx
    character(len=*), intent(in) :: input_text
    integer(c_int) :: rc
    character(kind=c_char, len=4096) :: cbuf
    integer :: n

    call set_c_string(input_text, cbuf, n)
    rc = chelpers_bind_text(stmt, int(idx, c_int), cbuf)
  end function bind_text

  function to_c_string(input_text) result(cstr)
    character(len=*), intent(in) :: input_text
    character(kind=c_char, len=4096), target :: cstr
    integer :: n

    cstr = c_null_char
    call set_c_string(input_text, cstr, n)
  end function to_c_string

  function from_c_string(cptr, max_len) result(text)
    type(c_ptr), intent(in) :: cptr
    integer, intent(in) :: max_len
    character(len=max_len) :: text
    character(kind=c_char), pointer :: chars(:)
    integer :: i, n

    text = ''
    if (.not. c_associated(cptr)) return
    call c_f_pointer(cptr, chars, [max_len])
    n = 0
    do i = 1, max_len
      if (chars(i) == c_null_char) exit
      n = n + 1
      text(n:n) = chars(i)
    end do
  end function from_c_string

end module sqlite_bind
