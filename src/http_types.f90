module http_types
  implicit none

  integer, parameter :: max_header_len = 8192
  integer, parameter :: max_body_len = 65536
  integer, parameter :: max_query_len = 4096

  type :: http_request
    character(len=16) :: method = ''
    character(len=2048) :: path = ''
    character(len=max_query_len) :: query = ''
    character(len=max_header_len) :: headers = ''
    character(len=max_body_len) :: body = ''
    character(len=512) :: auth_header = ''
    character(len=128) :: content_type = ''
  end type http_request

  type :: http_response
    integer :: status = 200
    character(len=512) :: content_type = 'application/json'
    character(len=max_body_len) :: body = ''
  end type http_response

end module http_types
