module chelpers_bind
  use iso_c_binding
  implicit none

  interface
    integer(c_int) function chelpers_bind_text(stmt, idx, text) bind(c)
      import c_char, c_int, c_ptr
      type(c_ptr), value :: stmt
      integer(c_int), value :: idx
      character(kind=c_char), intent(in) :: text(*)
    end function chelpers_bind_text

    integer(c_int) function chelpers_hash_password(password, out, out_len) bind(c)
      import c_char, c_int
      character(kind=c_char), intent(in) :: password(*)
      character(kind=c_char), intent(out) :: out(*)
      integer(c_int), value :: out_len
    end function chelpers_hash_password

    integer(c_int) function chelpers_verify_password(password, hash) bind(c)
      import c_char, c_int
      character(kind=c_char), intent(in) :: password(*)
      character(kind=c_char), intent(in) :: hash(*)
    end function chelpers_verify_password

    integer(c_int) function chelpers_jwt_create(email, secret, out, out_len) bind(c)
      import c_char, c_int
      character(kind=c_char), intent(in) :: email(*)
      character(kind=c_char), intent(in) :: secret(*)
      character(kind=c_char), intent(out) :: out(*)
      integer(c_int), value :: out_len
    end function chelpers_jwt_create

    integer(c_int) function chelpers_jwt_verify(token, secret, email, email_len) bind(c)
      import c_char, c_int
      character(kind=c_char), intent(in) :: token(*)
      character(kind=c_char), intent(in) :: secret(*)
      character(kind=c_char), intent(out) :: email(*)
      integer(c_int), value :: email_len
    end function chelpers_jwt_verify
  end interface

end module chelpers_bind
