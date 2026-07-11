module http_types
  implicit none

  integer, parameter :: max_header_len = 8192
  integer, parameter :: max_body_len = 65536

  type :: http_request
    character(len=16) :: method = ''
    character(len=2048) :: path = ''
    character(len=max_header_len) :: headers = ''
    character(len=max_body_len) :: body = ''
    character(len=512) :: auth_header = ''
  end type http_request

  type :: http_response
    integer :: status = 200
    character(len=512) :: content_type = 'application/json'
    character(len=max_body_len) :: body = ''
  end type http_response

end module http_types

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

end module json_util

module api_router
  use http_types
  use json_util
  implicit none

contains

  subroutine route_request(req, resp)
    type(http_request), intent(in) :: req
    type(http_response), intent(inout) :: resp

    if (trim(req%method) == 'GET' .and. trim(req%path) == '/') then
      resp%body = '{"message":"Hello from fortran-101"}'
      return
    end if

    if (trim(req%method) == 'GET' .and. trim(req%path) == '/health') then
      resp%body = '{"status":"ok"}'
      return
    end if

    if (trim(req%method) == 'GET' .and. trim(req%path) == '/categories') then
      resp%body = '{"items":[],"total":0,"skip":0,"limit":100}'
      return
    end if

    if (trim(req%method) == 'GET' .and. trim(req%path) == '/items') then
      resp%body = '{"items":[],"total":0,"skip":0,"limit":10}'
      return
    end if

    if (trim(req%method) == 'GET' .and. trim(req%path) == '/items/stats/summary') then
      resp%body = '{"total_items":0,"average_price":0.0,"min_price":null,"max_price":null,"uncategorized_count":0,"by_category":[]}'
      return
    end if

    resp%status = 404
    resp%body = '{"detail":"Not Found","code":"NOT_FOUND"}'
  end subroutine route_request

end module api_router

module http_server
  use iso_c_binding
  use http_types
  use api_router
  implicit none

  integer(c_int), parameter :: AF_INET = 2
  integer(c_int), parameter :: SOCK_STREAM = 1
  integer(c_int), parameter :: INADDR_ANY = 0

  type, bind(c) :: sockaddr_in
    integer(c_int16_t) :: sin_family
    integer(c_int16_t) :: sin_port
    integer(c_int32_t) :: sin_addr
    character(kind=c_char) :: sin_zero(8)
  end type sockaddr_in

  interface
    integer(c_int) function socket(domain, sock_type, protocol) bind(c, name='socket')
      import c_int
      integer(c_int), value :: domain, sock_type, protocol
    end function socket

    integer(c_int) function c_bind(sockfd, addr, addrlen) bind(c, name='bind')
      import c_int, sockaddr_in
      integer(c_int), value :: sockfd
      type(sockaddr_in) :: addr
      integer(c_int), value :: addrlen
    end function c_bind

    integer(c_int) function listen(sockfd, backlog) bind(c, name='listen')
      import c_int
      integer(c_int), value :: sockfd, backlog
    end function listen

    integer(c_int) function accept(sockfd, addr, addrlen) bind(c, name='accept')
      import c_int, c_ptr
      integer(c_int), value :: sockfd
      type(c_ptr), value :: addr
      type(c_ptr), value :: addrlen
    end function accept

    integer(c_int) function c_read(fd, buf, count) bind(c, name='read')
      import c_int, c_ptr, c_size_t
      integer(c_int), value :: fd
      type(c_ptr), value :: buf
      integer(c_size_t), value :: count
    end function c_read

    integer(c_int) function c_write(fd, buf, count) bind(c, name='write')
      import c_int, c_ptr, c_size_t
      integer(c_int), value :: fd
      type(c_ptr), value :: buf
      integer(c_size_t), value :: count
    end function c_write

    integer(c_int) function close(fd) bind(c, name='close')
      import c_int
      integer(c_int), value :: fd
    end function close

    integer(c_int16_t) function htons(hostshort) bind(c, name='htons')
      import c_int16_t
      integer(c_int16_t), value :: hostshort
    end function htons
  end interface

contains

  subroutine parse_request(raw, req)
    character(len=*), intent(in) :: raw
    type(http_request), intent(out) :: req
    integer :: line_end, header_start, body_start, i, pos1, pos2
    character(len=:), allocatable :: request_line, header_block

    req%method = ''
    req%path = ''
    req%headers = ''
    req%body = ''
    req%auth_header = ''

    line_end = index(raw, char(10))
    if (line_end == 0) return

    request_line = trim(adjustl(raw(1:line_end - 1)))
    if (len_trim(request_line) > 0 .and. request_line(len_trim(request_line):len_trim(request_line)) == char(13)) then
      request_line = request_line(1:len_trim(request_line) - 1)
    end if

    pos1 = index(request_line, ' ')
    if (pos1 == 0) return
    req%method = request_line(1:pos1 - 1)
    pos2 = index(request_line(pos1 + 1:), ' ')
    if (pos2 == 0) then
      req%path = trim(adjustl(request_line(pos1 + 1:)))
    else
      req%path = request_line(pos1 + 1:pos1 + pos2 - 1)
    end if
    if (index(req%path, '?') > 0) req%path = req%path(1:index(req%path, '?') - 1)

    header_start = line_end + 1
    body_start = index(raw(header_start:), char(10) // char(10))
    if (body_start == 0) then
      header_block = raw(header_start:)
      req%body = ''
    else
      body_start = header_start + body_start + 1
      header_block = raw(header_start:body_start - 3)
      req%body = adjustl(raw(body_start:))
    end if

    req%headers = header_block

    do i = 1, max(0, len_trim(header_block) - 13)
      if (header_block(i:i + 13) == 'Authorization:') then
        req%auth_header = trim(adjustl(header_block(i + 14:)))
        exit
      end if
    end do
  end subroutine parse_request

  function build_response(resp) result(payload)
    type(http_response), intent(in) :: resp
    character(len=:), allocatable :: payload
    character(len=32) :: status_text

    select case (resp%status)
    case (200); status_text = 'OK'
    case (201); status_text = 'Created'
    case (204); status_text = 'No Content'
    case (401); status_text = 'Unauthorized'
    case (404); status_text = 'Not Found'
    case (409); status_text = 'Conflict'
    case (422); status_text = 'Unprocessable Entity'
    case default; status_text = 'Internal Server Error'
    end select

    payload = 'HTTP/1.1 ' // trim(adjustl(write_status(resp%status))) // ' ' // trim(status_text) // char(13) // char(10) &
      // 'Content-Type: ' // trim(resp%content_type) // char(13) // char(10) &
      // 'Connection: close' // char(13) // char(10) &
      // 'Content-Length: ' // trim(adjustl(write_status(len_trim(resp%body)))) // char(13) // char(10) &
      // char(13) // char(10) // trim(resp%body)
  end function build_response

  function write_status(value) result(text)
    integer, intent(in) :: value
    character(len=32) :: text
    write (text, '(I0)') value
    text = trim(adjustl(text))
  end function write_status

  subroutine run_server(port)
    integer, intent(in) :: port

    integer(c_int) :: server_fd, client_fd, status, nbytes
    type(sockaddr_in) :: server_addr
    integer(c_int), parameter :: addr_len = 16
    character(kind=c_char), target :: buffer(65536)
    character(len=65536) :: chunk
    character(len=max_header_len + max_body_len) :: raw
    type(http_request) :: req
    type(http_response) :: resp
    character(len=:), allocatable :: payload
    integer :: i

    server_fd = socket(AF_INET, SOCK_STREAM, 0)
    if (server_fd < 0) then
      stop 'failed to create socket'
    end if

    server_addr%sin_family = AF_INET
    server_addr%sin_port = htons(int(port, c_int16_t))
    server_addr%sin_addr = INADDR_ANY
    do i = 1, 8
      server_addr%sin_zero(i) = char(0, kind=c_char)
    end do

    status = c_bind(server_fd, server_addr, addr_len)
    if (status < 0) then
      stop 'failed to bind socket'
    end if

    status = listen(server_fd, 32)
    if (status < 0) then
      stop 'failed to listen'
    end if

    print *, 'fortran-101 listening on port', port

    do
      client_fd = accept(server_fd, c_null_ptr, c_null_ptr)
      if (client_fd < 0) cycle

      raw = ''
      nbytes = c_read(client_fd, c_loc(buffer(1)), int(65536, c_size_t))
      if (nbytes > 0) then
        chunk = transfer(buffer(1:int(nbytes)), chunk)
        raw = trim(adjustl(chunk))
        call parse_request(raw, req)
        resp%status = 200
        resp%content_type = 'application/json'
        resp%body = ''
        call route_request(req, resp)
        payload = build_response(resp)
        buffer(1:len(payload)) = transfer(payload, buffer(1:len(payload)))
        status = c_write(client_fd, c_loc(buffer(1)), int(len(payload), c_size_t))
      end if

      status = close(client_fd)
    end do
  end subroutine run_server

end module http_server

program fortran_101
  use http_server
  implicit none

  integer :: port
  character(len=256) :: port_env

  port = 8008
  call get_environment_variable('APP_PORT', port_env)
  if (len_trim(port_env) > 0) read (port_env, *) port

  call run_server(port)
end program fortran_101
