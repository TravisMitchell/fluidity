! Handles output time period logic

#include "fdebug.h"

module time_period
  use FLDebug
  use global_parameters, only: OPTION_PATH_LEN
  use embed_python
  use spud
  use parallel_tools
  use timers

  implicit none

  !! Type for holding information about a previous dump period
  type time_period_type
    private

    !! whether the previous dump times have been initialised
    logical :: last_times_initialised = .false.

    !! the requested time between dumps in model seconds
    real :: real_dump_period = 0.0
    !! the requested time between dumps in timesteps
    integer :: int_dump_period = 0
    !! the last model time at which a dump was performed (or when this
    !! control struct was initialised)
    real :: last_dump_time

    !! the last cpu time at which a dump was performed
    real :: last_dump_cpu_time
    !! the last wall time at which a dump was performed
    real :: last_dump_wall_time
  end type time_period_type

contains
  function should_output(CS, current_time, timestep, option_path)
    !!< Given a time period control struct, should a new dump be
    !!< created at this moment in time (considering model time, the
    !!< current timestep, CPU time, and walltime)?

    logical :: should_output

    type(time_period_type), intent(inout) :: CS
    real, intent(in) :: current_time
    integer, intent(in) :: timestep

    character(len=*), intent(in) :: option_path

    integer :: stat
    real :: current_cpu_time, current_wall_time
    character(len=OPTION_PATH_LEN) :: func

    should_output = .false.

    if (.not. CS%last_times_initialised) then
      ! if the last_dump*_time variables have not been initialised, assume there should be output

      should_output = .true.
      return
    end if

    if (have_option(trim(option_path) // "/dump_period")) then
      ! dump period isn't set, or dump period has elapsed since the last time there was a dump

      ! avoid division by zero due to non-short-circuiting operator
      if (CS%real_dump_period == 0.0) then
        should_output = .true.
      else if (dump_count_greater(current_time, CS%last_dump_time, CS%real_dump_period)) then
        should_output = .true.
      end if

      if (should_output) then
        if (have_option(trim(option_path) // "/dump_period/constant")) then
          call get_option(trim(option_path) // "/dump_period/constant", CS%real_dump_period)
        else if (have_option(trim(option_path) // "/dump_period/python")) then
          call get_option(trim(option_path) // "/dump_period/python", func)
          call real_from_python(func, current_time, CS%real_dump_period)
        else
          FLAbort("Unable to determine dump period type.")
        end if

        if (CS%real_dump_period < 0.0) then
          FLExit("Dump period cannot be negative.")
        end if

        return
      end if
    end if

    if (have_option(trim(option_path) // "/dump_period_in_timesteps")) then
      ! timestep dump period isn't set, or the required number of timesteps has passed since the last dump

      if (CS%int_dump_period == 0) then
        should_output = .true.
      else if (mod(timestep, CS%int_dump_period) == 0) then
        should_output = .true.
      end if

      if (should_output) then
        if (have_option(trim(option_path) // "/dump_period_in_timesteps/constant")) then
          call get_option(trim(option_path) // "/dump_period_in_timesteps/constant", CS%int_dump_period)
        else if (have_option(trim(option_path) // "/dump_period_in_timesteps/python")) then
          call get_option(trim(option_path) // "/dump_period_in_timesteps/python", func)
          call integer_from_python(func, current_time, CS%int_dump_period)
        else
          FLAbort("Unable to determine dump period type.")
        end if

        if (CS%int_dump_period < 0) then
          FLExit("Dump period cannot be negative.")
        end if

        return
      end if
    end if

    if (.not. have_option(trim(option_path) // "/dump_period") .and. .not. have_option(trim(option_path) // "/dump_period_in_timesteps")) then
      ! if the option isn't set, assume always output

      should_output = .true.
      return
    end if

    call cpu_time(current_cpu_time)
    call allmax(current_cpu_time)
    call get_option(trim(option_path) // "/cpu_dump_period", CS%real_dump_period, stat)
    if (stat == SPUD_NO_ERROR) then
      if (CS%real_dump_period == 0.0) then
        should_output = .true.
        return
      else if (dump_count_greater(current_cpu_time, CS%last_dump_cpu_time, CS%real_dump_period)) then
        should_output = .true.
        return
      end if
    end if

    current_wall_time = wall_time()
    call allmax(current_wall_time)
    call get_option(trim(option_path) // "/wall_time_dump_period", CS%real_dump_period, stat)
    if (stat == SPUD_NO_ERROR) then
      if (CS%real_dump_period == 0.0) then
        should_output = .true.
        return
      else if (dump_count_greater(current_wall_time, CS%last_dump_wall_time, CS%real_dump_period)) then
        should_output = .true.
        return
      end if
    end if

  contains
    pure function dump_count_greater(later_time, earlier_time, dump_period)
      !!< Return whether the total number of dumps at time later_time is greater
      !!< than the total number of dumps at time earlier_time.

      logical :: dump_count_greater

      real, intent(in) :: later_time, earlier_time, dump_period

      dump_count_greater = floor(later_time / dump_period) > floor(earlier_time / dump_period)
    end function dump_count_greater
  end function should_output

  subroutine init_output_CS(CS, option_path)
    !!< Initialise a time period control structure, reading options
    !!< from the specified option_path.

    type(time_period_type), intent(inout) :: CS
    character(len=*), intent(in) :: option_path !! path prefix for reading options

    character(len=OPTION_PATH_LEN) :: func

    call get_option("/timestepping/current_time", CS%last_dump_time)

    if (have_option(trim(option_path) // "/dump_period/constant")) then
      call get_option(trim(option_path) // "/dump_period/constant", CS%real_dump_period)

    else if (have_option(trim(option_path) // "/dump_period/python")) then
      ! set a dummy dump period and call to the set function -- we don't count this as
      ! initialising the last dump time (unlike update_output_CS)
      CS%real_dump_period = huge(0.0)
      call get_option(trim(option_path) // "/dump_period/python", func)
      call real_from_python(func, CS%last_dump_time, CS%real_dump_period)

      if (CS%real_dump_period < 0.0) then
        FLExit("Dump period cannot be negative.")
      end if

    else if (have_option(trim(option_path) // "/dump_period_in_timesteps/constant")) then
      call get_option(trim(option_path) // "/dump_period_in_timesteps/constant", CS%int_dump_period)

    else if (have_option(trim(option_path) // "/dump_period_in_timesteps/python")) then
      ! set a dummy period and call the function
      CS%int_dump_period = huge(0)
      call get_option(trim(option_path) // "/dump_period_in_timesteps/python", func)
      call integer_from_python(func, CS%last_dump_time, CS%int_dump_period)

      if (CS%int_dump_period < 0) then
        FLExit("Dump period cannot be negative.")
      end if
    end if
  end subroutine init_output_CS

  subroutine update_output_CS(CS, current_time)
    !!< Update the given time period control structure after
    !!< a dump has been made.

    type(time_period_type), intent(inout) :: CS
    real, intent(in) :: current_time

    CS%last_times_initialised = .true.

    ! update model, cpu and walltimes in the structure
    CS%last_dump_time = current_time

    call cpu_time(CS%last_dump_cpu_time)
    call allmax(CS%last_dump_cpu_time)

    CS%last_dump_wall_time = wall_time()
    call allmax(CS%last_dump_wall_time)
  end subroutine update_output_CS
end module time_period
