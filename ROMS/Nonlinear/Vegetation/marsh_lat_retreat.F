#include "cppdefs.h"

      MODULE marsh_lat_retreat_mod

#if defined SEDIMENT && defined BEDLOAD && defined MARSH_WAVE_THRUST \
    && defined MARSH_LAT_RETREAT_MODE1 
!
!svn $Id: marsh_wave_thrust.F 429 2015-04-20 17:30:26Z arango $
!=======================================================================
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license           Hernan G. Arango   !
!    See License_ROMS.txt                   Alexander F. Shchepetkin   !
!================================================Neil K. Ganju  =======!
!==============================================Tarandeep S. Kalra======!
!==============================================John C. Warner==========!
!                                                                      ! 
!  References:                                                         !
!                                                                      !
!=======================================================================
!
      implicit none

      PRIVATE
      PUBLIC  :: marsh_lat_retreat_mode1

      CONTAINS
!
!***********************************************************************
      SUBROUTINE marsh_lat_retreat_mode1 (ng, tile)
!***********************************************************************
!
      USE mod_param
      USE mod_forces
      USE mod_grid
      USE mod_ocean
      USE mod_vegetation 
      USE mod_vegarr
      USE mod_sedbed
      USE mod_stepping
      USE marsh_wave_thrust_mod
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
!
!  Local variable declarations.
!
# include "tile.h"
!
# ifdef PROFILE
      CALL wclock_on (ng, iNLM, 16)
# endif
      CALL marsh_lat_retreat_mode1_tile (ng, tile,                      &
     &                       LBi, UBi, LBj, UBj,                        &
     &                       IminS, ImaxS, JminS, JmaxS,                &
     &                       GRID(ng) % om_r,                           &
     &                       GRID(ng) % on_r,                           &
     &                       GRID(ng) % h,                              &
     &                       OCEAN(ng) % zeta,                          & 
     &                       VEG(ng) % marsh_mask,                      & 
     &                       VEG(ng) % marsh_flux_e,                    &
     &                       VEG(ng) % marsh_flux_w,                    &
     &                       VEG(ng) % marsh_flux_n,                    &
     &                       VEG(ng) % marsh_flux_s,                    & 
     &                       SEDBED(ng) % bed,                          &
     &                       VEG(ng) % marsh_retreat)
# ifdef PROFILE
      CALL wclock_off (ng, iNLM, 16)
# endif
      RETURN
      END SUBROUTINE marsh_lat_retreat_mode1
!
!***********************************************************************
!
      SUBROUTINE marsh_lat_retreat_mode1_tile (ng, tile,                &
     &                             LBi, UBi, LBj, UBj,                  &
     &                             IminS, ImaxS, JminS, JmaxS,          &
     &                             om_r, on_r,                          &
     &                             h, zeta,                             &
     &                             marsh_mask,                          &
     &                             marsh_flux_e, marsh_flux_w,          &
     &                             marsh_flux_n, marsh_flux_s,          & 
     &                             bed,                                 &
     &                             marsh_retreat)
!
!***********************************************************************
!
      USE mod_param
      USE mod_ncparam
      USE mod_scalars
      USE mod_vegetation 
      USE mod_vegarr
      USE mod_sediment
      USE marsh_wave_erode_mod
      USE bc_2d_mod, ONLY : bc_r2d_tile
      USE bc_3d_mod, ONLY : bc_r3d_tile

      USE exchange_2d_mod, ONLY : exchange_r2d_tile
# ifdef DISTRIBUTE
      USE mp_exchange_mod, ONLY : mp_exchange2d, mp_exchange3d
      USE mp_exchange_mod, ONLY : mp_exchange4d
# endif
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
      integer, intent(in) :: LBi, UBi, LBj, UBj
      integer, intent(in) :: IminS, ImaxS, JminS, JmaxS
      integer, intent(in) :: nstp, nnew
!
# ifdef ASSUMED_SHAPE
      real(r8), intent(in) :: om_r(LBi:,LBj:)
      real(r8), intent(in) :: on_r(LBi:,LBj:)
      real(r8), intent(in) :: h(LBi:,LBj:)
      real(r8), intent(in) :: zeta(LBi:,LBj:,:)
!
      real(r8), intent(in) :: marsh_mask(LBi:,LBj:)
      real(r8), intent(in) :: marsh_flux_w(LBi:,LBj:)
      real(r8), intent(in) :: marsh_flux_e(LBi:,LBj:)
      real(r8), intent(in) :: marsh_flux_n(LBi:,LBj:)
      real(r8), intent(in) :: marsh_flux_s(LBi:,LBj:)
! 
      real(r8), intent(in) :: bed(LBi:,LBj:,:,:)
!
      real(r8), intent(inout) :: marsh_retreat(LBi:,LBj:)
# else
      real(r8), intent(in) :: om_r(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: on_r(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: h(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: zeta(LBi:UBi,LBj:UBj,3)
!
      real(r8), intent(in) :: marsh_mask(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: marsh_flux_w(LBi:UBi,LBj:UBj) 
      real(r8), intent(in) :: marsh_flux_e(LBi:UBi,LBj:UBj) 
      real(r8), intent(in) :: marsh_flux_n(LBi:UBi,LBj:UBj) 
      real(r8), intent(in) :: marsh_flux_s(LBi:UBi,LBj:UBj)
!
      real(r8), intent(in) :: bed(LBi:UBi,LBj:UBj,Nbed,MBEDP)
!
      real(r8), intent(inout) :: marsh_retreat(LBi:UBi,LBj:UBj)
# endif
!
!  Local variable declarations.
!
      integer :: i, ised, iveg, j, k
      real(r8) :: cff, cff1, cff2, cff3, cff4
!
!-----------------------------------------------------------------------
! Save the initial in a local array bed_ini 
! The change in marsh erosion uses this array
!-----------------------------------------------------------------------
!
      real(r8), dimension(IminS:ImaxS,JminS:JmaxS,NST) :: bed_ini
      real(r8) :: Thrust_crit, crit_bed_mass
      real(r8) :: Eff_thrust 
      real(r8), parameter :: eps = 1.0E-14_r8 ! , dcrit_marsh=0.5_r8 
!
# include "set_bounds.h"
!
!-----------------------------------------------------------------------
! Compute some constant of marsh sediment (May be would be input). 
!-----------------------------------------------------------------------
!     
! Critical thrust or erosion thrust value to be decided 
!
      Thrust_crit=0.0_r8
!
      DO ised=NCS+1,NST
        DO j=Jstr,Jend
          DO i=Istr,Iend
! 
! Get the area and effective density to obtain eroded volume 
! 
            cff=1.0_r8/(om_r(i,j)*on_r(i,j))
            cff1=1.0_r8/(Srho(ised,ng)*(1.0_r8-bed_poros(i,j,1,ised)))
            scarp_height_eff=h(i,j)+zeta(i,j,3)
!
!  |           | Flux North  |         |
!--|---------- |-------------|---------|-------------
!  |Flux West  |   Marsh     |Flux East| 
!  |-----------|-------------|---------|
!  |           |Flux South   |         |    
!
!-----------------------------------------------------------------------
! West cell face erosion volume
!-----------------------------------------------------------------------
!
            Vol_erod=marsh_flux_w(i,j)*cff*cff1
            dx_e=Vol_erod/(scarp_height_eff*on_r(i,j))
!
!-----------------------------------------------------------------------
! East cell face erosion volume
!-----------------------------------------------------------------------
!
            Vol_erod=marsh_flux_e(i+1,j)*cff*cff1
            dx_w=Vol_erod/(scarp_height_eff*on_r(i,j))
!
!-----------------------------------------------------------------------
! North cell face erosion volume
!-----------------------------------------------------------------------
!
            Vol_erod=marsh_flux_n(i,j+1)*cff*cff1
            dy_n=Vol_erod/(scarp_height_eff*om_r(i,j))
!
!-----------------------------------------------------------------------
! South cell face erosion volume
!-----------------------------------------------------------------------
!
            Vol_erod=marsh_flux_s(i,j)*cff*cff1
            dy_s=Vol_erod/(scarp_height_eff*om_r(i,j))
!
            marsh_retreat(i,j)=marsh_mask(i,j)*(dx_e+dx_w+dy_n+dy_s)
!
          END DO
        END DO 
      END DO
!
!---------------------------------------------------------------------
!  Apply periodic or gradient boundary conditions for output
!  purposes only.
!---------------------------------------------------------------------
!
      CALL bc_r2d_tile (ng, tile,                                       &
     &                  LBi, UBi, LBj, UBj,                             &
     &                  marsh_retreat)
# ifdef DISTRIBUTE
        CALL mp_exchange2d (ng, tile, iNLM, 2,                          &
     &                        LBi, UBi, LBj, UBj,                       &
     &                        NghostPoints,                             &
     &                        EWperiodic(ng), NSperiodic(ng),           &
     &                        marsh_retreat)
# endif
!
      RETURN
      END SUBROUTINE marsh_lat_retreat_mode1_tile
#endif
      END MODULE marsh_lat_retreat_mode1_mod
