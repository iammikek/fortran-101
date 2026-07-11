module json_util
  implicit none

contains

  function json_escape(value) result(escaped)
    character(len=*), intent(in) :: value
    character(len=:), allocatable :: escaped
    integer :: i
    character(len=1) :: ch

    escaped = ''
    do i = 1, len_trim(value)
      ch = value(i:i)
      select case (ch)
      case ('"')
        escaped = escaped // '\"'
      case ('\')
        escaped = escaped // '\\'
      case (char(10))
        escaped = escaped // '\n'
      case default
        escaped = escaped // ch
      end select
    end do
  end function json_escape

  function json_string_or_null(value) result(json)
    character(len=*), intent(in) :: value
    character(len=:), allocatable :: json

    if (len_trim(value) == 0) then
      json = 'null'
    else
      json = '"' // json_escape(trim(value)) // '"'
    end if
  end function json_string_or_null

  function json_number(value) result(json)
    real, intent(in) :: value
    character(len=64) :: json
    integer :: int_val

    int_val = nint(value * 100.0)
    if (abs(value * 100.0 - real(int_val)) < 0.001) then
      if (abs(value - nint(value)) < 0.001) then
        write (json, '(I0)') nint(value)
      else
        write (json, '(F0.2)') value
      end if
    else
      write (json, '(F0.2)') value
    end if
    json = trim(adjustl(json))
  end function json_number

  subroutine error_json(resp, detail, status, code)
    use http_types
    type(http_response), intent(inout) :: resp
    character(len=*), intent(in) :: detail
    integer, intent(in) :: status
    character(len=*), intent(in), optional :: code

    resp%status = status
    if (present(code)) then
      resp%body = '{"detail":"' // json_escape(trim(detail)) // '","code":"' // trim(code) // '"}'
    else
      resp%body = '{"detail":"' // json_escape(trim(detail)) // '"}'
    end if
  end subroutine error_json

end module json_util
