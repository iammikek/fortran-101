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
