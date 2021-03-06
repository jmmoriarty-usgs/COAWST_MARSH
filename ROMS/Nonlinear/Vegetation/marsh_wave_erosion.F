#include "cppdefs.h"
 
       MODULE marsh_wave_erosion_mod
#if defined VEGETATION && defined MARSH_WAVE_EROSION
!
!svn $Id: marsh_wave_thrust.F 429 2015-04-20 17:30:26Z arango $
!=======================================================================
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license           Hernan G. Arango   !
!    See License_ROMS.txt                   Alexander F. Shchepetkin   !
!================================================John C. Warner=========
!================================================Neil K. Ganju  ========
!==============================================Tarandeep S. Kalra=======
!                                                                      ! 
!  This routine calls three sub-routines.                              !
!  1. Compute wave thrust on marshes.                                  !
!     --> marsh_wave_thrust.F                                          !
!  2. Obtain sediment erosion from one of the two user defined methods.!
!     --> marsh_sed_bedload_mode1.F                                    !
!     --> marsh_sed_bedload_mode2.F                                    !
!  3. Get the amount of lateral retreat based on mass flux.            !
!     --> marsh_lat_retreat.F                                          !
!                                                                      !
!  References:                                                         !   
!                                                                      !
!======================================================================! 
!                                                                      !
      implicit none

      PRIVATE
      PUBLIC  :: marsh_wave_erosion

      CONTAINS
!
!***********************************************************************
!
      SUBROUTINE marsh_wave_erosion (ng, tile)
!
!***********************************************************************
!
# if defined MARSH_WAVE_THRUST 
      USE mod_marsh_wave_thrust, ONLY : marsh_wave_thrust
#  if defined MARSH_SED_BEDLOAD_MODE1
       USE mod_marsh_sed_bedload_mode1, ONLY : marsh_sed_bedload_mode1 
#  endif 
#  if defined MARSH_SED_BEDLOAD_MODE2
       USE mod_marsh_sed_bedload_mode2, ONLY : marsh_sed_bedload_mode2
#  endif 
#  if defined MARSH_LAT_RETREAT
       USE mod_marsh_lat_retreat, ONLY : marsh_lat_retreat
#  endif 
# endif 
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
!

# ifdef PROFILE
      CALL wclock_on (ng, iNLM, 16)
# endif
!
# if defined MARSH_WAVE_THRUST
!
!***********************************************************************
! Wave induced thrust calculation on marsh boundary.
!***********************************************************************
!
      CALL marsh_wave_thrust_mod(ng, tile)
!
#  if defined MARSH_SED_BEDLOAD_MODE1
!
!***********************************************************************
! Marsh sediment erosion based on bathy change in marsh cells.
!***********************************************************************
!
      CALL marsh_sed_bedload_mode1_mod(ng, tile) 
!
#  if defined MARSH_SED_BEDLOAD_MODE2
!
!***********************************************************************
! Marsh sediment erosion based on fixed bathy in marsh cells.
!***********************************************************************
!
      CALL marsh_sed_bedload_mode2_mod(ng, tile) 
!
#  if defined MARSH_LAT_RETREAT
!
!***********************************************************************
! Compute effective lateral retreat. 
!***********************************************************************
!
      CALL marsh_lat_retreat_mod(ng, tile) 
!
#  endif 
              
# ifdef PROFILE
      CALL wclock_off (ng, iNLM, 16)
# endif
      RETURN
      END SUBROUTINE marsh_wave_erosion
#endif
      END MODULE marsh_wave_erosion_mod
