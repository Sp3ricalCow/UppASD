!-------------------------------------------------------------------------------
! MODULE: qminimizer
!> @brief
!> Spin-spiral energy minimization
!> @author
!> Anders Bergman
!> @copyright
!> GNU Public License.
!-------------------------------------------------------------------------------
module qminimizer
   use Parameters
   use Profiling
   use FieldData
   use HamiltonianActions
   !
   !
   implicit none
   !
   real(dblprec) :: fac_2d
   !
   !
   ! Input parameters
   !
   integer, parameter :: nq=1
   !
   !
   ! Data for minimization and ss-vectors
   real(dblprec), dimension(3,3) :: q  !< q-vector for spin spiral
   real(dblprec), dimension(3,3) :: s  !< 
   real(dblprec), dimension(3) :: n_vec !< unit-vector perpendicular to spins
   real(dblprec), dimension(3) :: theta, phi
   real(dblprec) :: theta_glob
   !
   character*1 :: qm_rot   !< Rotate magnetic texture instead of pure spin spirals
   character*1 :: qm_oaxis !< Ensure that the rotational axis is perpendicular to m
   character*1 :: qm_type  !< Which type of qm_axis to use (C)ycloidal, (H)elical, or (G)eneral
   !
   ! Control parameters for line sweep
   real(dblpreC) :: q_min
   real(dblpreC) :: q_max
   integer :: nstep
   !
   private
   !
   !public :: mini_q, plot_q, qmc, sweep_q2, sweep_q3, plot_q3
   !public :: plot_q, qmc, sweep_q2, sweep_q3, plot_q3
   !public :: sweep_cube, plot_cube
   public :: read_parameters_qminimizer,qminimizer_init, qminimizer_wrapper
   !public :: sweep_q,read_parameters_qminimizer,qminimizer_init
   !
contains

   subroutine qminimizer_wrapper(qmode)
      !
      use InputData!, only : Natom, Mensemble, NA
      use optimizationRoutines, only : OPT_flag,max_no_constellations,maxNoConstl,unitCellType,constlNCoup, constellations,constellationsNeighType
      use macrocells, only : Num_macro,cell_index, emomM_macro,macro_nlistsize
      use MomentData, only : emom, emomM, mmom
      use SystemData, only : coord
      use Qvectors,   only : q, nq

      implicit none
      !
      character*1, intent(in) :: qmode

      !

      if (qmode=='Q') then
         ! Spin spiral minimization initial phase
         !call mini_q(Natom,Mensemble,NA,coord,do_jtensor,exc_inter,do_dm,do_pd,          &
         call sweep_q2(Natom,Mensemble,NA,coord,emomM,mmom,iphfield,    &
            OPT_flag,max_no_constellations,maxNoConstl,unitCellType,constlNCoup,    &
            constellations,constellationsNeighType,Num_macro,cell_index,  &
            emomM_macro,macro_nlistsize,simid,q,nq)
         call plot_q(Natom,Mensemble,coord,emom,emomM,mmom,simid)
      elseif (qmode=='Z') then
         ! Spin spiral minimization initial phase
         !call mini_q(Natom,Mensemble,NA,coord,do_jtensor,exc_inter,do_dm,do_pd,          &
         !call sweep_q3(Natom,Mensemble,NA,coord,do_jtensor,exc_inter,do_dm,do_pd,    &
         call sweep_cube(Natom,Mensemble,NA,coord,emomM,mmom,iphfield,    &
            OPT_flag,max_no_constellations,maxNoConstl,unitCellType,constlNCoup,    &
            constellations,constellationsNeighType,Num_macro,cell_index,  &
            emomM_macro,macro_nlistsize,simid,q,nq)
         call plot_cube(Natom,Mensemble,coord,emom,emomM,mmom,simid)
      elseif (qmode=='Y') then
         ! Spin spiral minimization initial phase
         call sweep_q3(Natom,Mensemble,NA,coord,emomM,mmom,iphfield,    &
            OPT_flag,max_no_constellations,maxNoConstl,unitCellType,constlNCoup,    &
            constellations,constellationsNeighType,Num_macro,cell_index,  &
            emomM_macro,macro_nlistsize,simid,q,nq)
         call plot_q3(Natom,Mensemble,coord,emom,emomM,mmom,simid)
      elseif (mode=='S') then
         ! Spin spiral minimization measurement phase
         call qmc(Natom,Mensemble,NA,N1,N2,N3,coord, emomM,mmom,hfield,&
            OPT_flag,max_no_constellations,maxNoConstl,unitCellType,constlNCoup,    &
            constellations,constellationsNeighType,Num_macro,cell_index,  &
            emomM_macro,macro_nlistsize)
         call plot_q(Natom, Mensemble, coord, emom, emomM, mmom,simid)

      end if
   
   end subroutine qminimizer_wrapper
!!!    !-----------------------------------------------------------------------------
!!!    ! SUBROUTINE: mini_q
!!!    !> @brief Main driver for the minimization of spin spirals
!!!    !> @author Anders Bergman
!!!    !-----------------------------------------------------------------------------
!!!    subroutine mini_q(Natom,Mensemble,NA,coord,do_jtensor,exc_inter,do_dm,do_pd,     &
!!!       do_biqdm,do_bq,do_chir,taniso,sb,do_dip,emomM,mmom,hfield,OPT_flag,           &
!!!       max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
!!!       constellationsNeighType,mult_axis,Num_macro,cell_index,emomM_macro,           &
!!!       macro_nlistsize,do_anisotropy)
!!! 
!!!       use RandomNumbers, only: rng_uniform,rng_gaussian, use_vsl
!!!       use Constants, only : mub, mry
!!!       use InputData, only : N1,N2,N3
!!!       !
!!!       !.. Implicit declarations
!!!       implicit none
!!! 
!!!       integer, intent(in) :: Natom !< Number of atoms in system
!!!       integer, intent(in) :: Mensemble !< Number of ensembles
!!!       integer, intent(in) :: NA  !< Number of atoms in one cell
!!!       real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
!!!       integer, intent(in) :: do_jtensor   !<  Use SKKR style exchange tensor (0=off, 1=on, 2=with biquadratic exchange)
!!!       character(len=1),intent(in) :: exc_inter !< Interpolate Jij (Y/N)
!!!       integer, intent(in) :: do_dm   !< Add Dzyaloshinskii-Moriya (DM) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_pd   !< Add Pseudo-Dipolar (PD) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_biqdm   !< Add Biquadratic DM (BIQDM) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_bq   !< Add biquadratic exchange (BQ) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_chir  !< Add scalar chirality exchange (CHIR) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_dip  !<  Calculate dipole-dipole contribution (0/1)
!!!       integer, intent(in) :: do_anisotropy
!!!       integer, dimension(Natom),intent(in) :: taniso !< Type of anisotropy (0-2)
!!!       real(dblprec), dimension(Natom),intent(in) :: sb !< Ratio between the anisotropies
!!!       real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
!!!       real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
!!!       real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
!!!       character(len=1), intent(in) :: mult_axis
!!!       !! +++ New variables due to optimization routines +++ !!
!!!       integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
!!!       ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
!!!       integer, dimension(Mensemble), intent(in) :: maxNoConstl
!!!       ! See OptimizationRoutines.f90 for details on classification
!!!       integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
!!!       ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
!!!       real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
!!!       ! Matrix storing all unit cells belonging to any constellation
!!!       real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
!!!       ! Optimization flag (1 = optimization on; 0 = optimization off)
!!!       logical, intent(in) :: OPT_flag
!!!       ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
!!!       ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
!!!       integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
!!!       ! Internal effective field arising from the optimization of the Heissenberg exchange term
!!!       integer, intent(in) :: Num_macro !< Number of macrocells in the system
!!!       integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
!!!       integer, dimension(Num_macro), intent(in) :: macro_nlistsize !< Number of atoms per macrocell
!!!       real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
!!!       !
!!!       integer :: iq
!!!       !
!!!       real(dblprec), dimension(3) :: m_i, m_j, r_i, r_j, m_avg
!!!       real(dblprec) :: pi, qr, rx,ry, rz
!!!       integer :: i,j, k, iia, ia, ja, lhit, nhits, countstart
!!!       real(dblprec) :: energy, min_energy
!!!       !
!!!       real(dblprec), dimension(3,3) :: q_best, q_diff, s_diff, q_0, s_0, q_norm
!!!       real(dblprec), dimension(3,3) :: s_save, q_save
!!!       real(dblprec), dimension(3) :: theta_save, theta_diff, theta_best
!!!       real(dblprec) :: theta_glob_save, cone_ang, cone_ang_save
!!!       real(dblprec) :: theta_glob_diff, theta_glob_best
!!!       real(dblprec), dimension(3) :: phi_save, phi_diff, phi_best
!!!       real(dblprec), dimension(1) :: cone_ang_diff
!!!       real(dblprec), dimension(1) :: rng_tmp_arr
!!!       integer :: niter, iter, iscale, i1 ,i2 ,i3
!!!       real(dblprec) :: q_range, theta_range, s_range, phi_range, theta_glob_range, cone_ang_range
!!!       real(dblprec) :: q_range0, theta_range0, s_range0, phi_range0, theta_glob_range0
!!!       real(dblprec), dimension(3) :: srvec 
!!!       !
!!!       !
!!!       real(dblprec) :: q_start=1.0_dblprec
!!!       !
!!!       !
!!!       pi=4._dblprec*ATAN(1._dblprec)
!!!       theta_glob_best=0.0_dblprec
!!!       theta_best=0.0_dblprec
!!!       phi_best=0.0_dblprec
!!!       !
!!!       ! Normal vector
!!!       n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec;
!!!       !
!!!       ! Starting atom
!!!       I1 = N1/2
!!!       I2 = N2/2
!!!       I3 = N3/2
!!! 
!!!       countstart = 0+I1*NA+I2*N1*NA+I3*N2*N1*NA
!!!       print *, 'CountStart: ',countstart
!!!       !
!!!       niter=10000
!!!       ! Hard wired to planar spin spirals with 360/nq degree angle inbetween
!!!       !
!!!       theta = 0.0_dblprec
!!!       theta_glob = 0.0_dblprec
!!!       !theta_glob = pi/4.0_dblprec
!!!       phi = 0.0_dblprec
!!!       do iq=1,nq
!!!          ! Start along [100] direction
!!!          q(1,iq)=1.0_dblprec;q(2,iq)=0.0_dblprec;q(3,iq)=0.0_dblprec
!!!          !! Start along [100] direction
!!!          call normalize(q(1:3,iq))
!!!          ! Rotate 360/iq
!!!          theta(iq)=2.0_dblprec*pi/nq*(iq-1.0_dblprec)
!!!          rx= q(1,iq)*cos(theta(iq)+theta_glob)+q(2,iq)*sin(theta(iq)+theta_glob)
!!!          ry=-q(1,iq)*sin(theta(iq)+theta_glob)+q(2,iq)*cos(theta(iq)+theta_glob)
!!!          q(1,iq)=rx
!!!          q(2,iq)=ry
!!!          q(3,iq)=0.0_dblprec
!!!          !
!!!          q_norm(:,iq)=q(:,iq)/sqrt(sum(q(:,iq)*q(:,iq))+1.0e-12_dblprec)
!!!          !
!!!          ! Create pitch vectors perpendicular to q
!!!          if(norm2(s(:,iq))==0.0_dblprec) then
!!!             s(1,iq)=q_norm(2,iq)*n_vec(3)-q_norm(3,iq)*n_vec(2)
!!!             s(2,iq)=q_norm(3,iq)*n_vec(1)-q_norm(1,iq)*n_vec(3)
!!!             s(3,iq)=q_norm(1,iq)*n_vec(2)-q_norm(2,iq)*n_vec(1)
!!!          end if
!!!          call normalize(s(1:3,iq))
!!!          !
!!!          print *,'----Q-and-S-vectors----',iq
!!!          print '(3f10.4)', q(:,iq)
!!!          print '(3f10.4)', s(:,iq)
!!!          !
!!!          ! Currently hard wired starting guess
!!!          q(:,iq)=q(:,iq)/sqrt(sum(q(:,iq)*q(:,iq))) *q_start  !/30.0_dblprec
!!!          !
!!!       end do
!!!       q_0=q
!!!       ! For Neel spirals:
!!!       !s=q_norm
!!!       !do iq=1,nq
!!!       !   print *,'----Q_0 vector----',iq
!!!       !   print '(3f10.4)', q_0(:,iq)
!!!       !end do
!!!       s_0=s
!!!       min_energy=1.0d4
!!!       ! Set starting minimization ranges
!!!       q_range0=1.0_dblprec
!!!       s_range0=0
!!!       theta_range0=0
!!!       theta_glob_range0= 1.0_dblprec
!!!       phi_range0=0.0_dblprec
!!!       cone_ang_range=0
!!!       ! Real ranges (scaled during the minimization)
!!!       q_range=q_range0
!!!       s_range=s_range0
!!!       theta_range=theta_range0
!!!       theta_glob_range=theta_glob_range0
!!!       phi_range=phi_range0
!!!       !
!!!       lhit=0
!!!       nhits=0
!!!       iscale=1
!!! 
!!!       ! Legacy code for 2d-systems
!!!       fac_2d=1.0_dblprec
!!!       ! Switch rotation direction
!!! 
!!!       ! Calculate total external field (not included yet)
!!!       do k=1,Mensemble
!!!          do i=1,Natom
!!!             external_field(1:3,i,k)= hfield
!!!             beff(1:3,i,k)=0.0_dblprec
!!!             beff1(1:3,i,k)=0.0_dblprec
!!!             beff2(1:3,i,k)=0.0_dblprec
!!!          end do
!!!       end do
!!! 
!!!       do iter=0,niter
!!! !         !
!!! !         q_diff=0.0_dblprec
!!! !         call rng_uniform(q_diff(1,1),1)
!!! !         q_diff(1,1)=2.0_dblprec*q_diff(1,1)-1.0_dblprec
!!! !         q_diff(2,1)=0.0_dblprec
!!! !         q_diff(3,1)=0.0_dblprec
!!! !         q_diff=q_diff*q_range
!!! !         !
!!! !         theta_save=theta
!!! !         phi_save=phi
!!! !         do iq=1,nq
!!! !            theta_diff(iq)=0.0_dblprec
!!! !            ! phi angle
!!! !            call rng_uniform(phi_diff(iq),1)
!!! !            phi_diff(iq)=0.0_dblprec
!!! !            !
!!! !         end do
!!! !         theta=theta+theta_diff
!!! !         phi=phi+phi_diff
!!! !         !
!!! !         ! global theta angle
!!! !         theta_glob_save=theta_glob
!!! !         call rng_uniform(rng_tmp_arr,1)
!!! !         theta_glob_diff=rng_tmp_arr(1)
!!! !         theta_glob_diff=(theta_glob_diff-0.5_dblprec)*theta_glob_range*2*pi
!!! !         theta_glob=theta_glob+theta_glob_diff
!!! !         ! Set up trial vectors
!!! !         energy=0.0_dblprec
!!! !         q_save=q
!!! !         q(:,1)=q(:,1)+q_diff(:,1)
!!! !         ! Local rotations
!!! !         do iq=1,nq
!!! !            rx= q(1,1)*cos(theta(iq))+q(2,1)*sin(theta(iq))
!!! !            ry=-q(1,1)*sin(theta(iq))+q(2,1)*cos(theta(iq))
!!! !            q(1,iq)=rx
!!! !            q(2,iq)=ry
!!! !            q(3,iq)=0.0_dblprec
!!! !         end do
!!! !         ! Global rotation
!!! !         do iq=1,nq
!!! !            rx= q(1,iq)*cos(theta_glob)+q(2,iq)*sin(theta_glob)
!!! !            ry=-q(1,iq)*sin(theta_glob)+q(2,iq)*cos(theta_glob)
!!! !            q(1,iq)=2.0_dblprec*((0.1_dblprec*iter)/(1.0_dblprec*niter)-0.05_dblprec)
!!! !            q(2,iq)=0.0_dblprec
!!! !            q(3,iq)=0.0_dblprec
!!! !         end do
!!!          do iq=1,nq
!!!             q(:,iq)=q_0(:,iq)-q_0(:,iq)/sqrt(sum(q_0(:,iq)**2))*(2.0_dblprec*q_start*iter)/(1.0_dblprec*niter)
!!!          end do
!!! !         !
!!!          s_save=s
!!!          cone_ang=0.0_dblprec
!!! 
!!!          ! Fold back to wanted range
!!!          do iq=1,nq
!!!             if(theta(iq)>pi) theta(iq)=theta(iq)-pi*2.0_dblprec
!!!             if(theta(iq)<-pi) theta(iq)=theta(iq)+pi*2.0_dblprec
!!!             if(phi(iq)>pi) phi(iq)=phi(iq)-pi*2.0_dblprec
!!!             if(phi(iq)<-pi) phi(iq)=phi(iq)+pi*2.0_dblprec
!!!             if(q(1,iq)>1.0_dblprec) q(1,iq)=q(1,iq)-2.0_dblprec
!!!             if(q(2,iq)>1.0_dblprec) q(2,iq)=q(2,iq)-2.0_dblprec
!!!             if(q(3,iq)>1.0_dblprec) q(3,iq)=q(3,iq)-2.0_dblprec
!!!             if(q(1,iq)<-1.0_dblprec) q(1,iq)=q(1,iq)+2.0_dblprec
!!!             if(q(2,iq)<-1.0_dblprec) q(2,iq)=q(2,iq)+2.0_dblprec
!!!             if(q(3,iq)<-1.0_dblprec) q(3,iq)=q(3,iq)+2.0_dblprec
!!!          end do
!!!          !
!!!          ! Set up spin-spiral magnetization (only first cell+ neighbours)
!!!          do k=1,Mensemble
!!!             energy=0.0_dblprec
!!!             do ia=1,Natom
!!!             !  lhit=lhit+1
!!!                srvec=coord(:,ia)-coord(:,countstart+1)
!!!                !
!!!                m_j=0.0_dblprec
!!!                do iq=1,nq
!!!                   qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
!!!                   m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
!!!                end do
!!!                call normalize(m_j)
!!!                !emom(1:3,ia,k)=m_j
!!!                emomM(1:3,ia,k)=m_j*mmom(ia,k)
!!!                !write(ofileno,'(2i8,4f14.6)') 1,lhit,mmom(ia,k),m_j
!!!             !  write(ofileno,'(2i8,4f14.6)') 1,ia,mmom(ia,k),m_j
!!!             end do
!!! !        do ia=1,NA
!!! !        !  lhit=lhit+1
!!! !           iia=ia+countstart
!!! !           srvec=coord(:,iia)-coord(:,countstart+1)
!!! !           !
!!! !           m_j=0.0_dblprec
!!! !           do iq=1,nq
!!! !              qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
!!! !              m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
!!! !           end do
!!! !           call normalize(m_j)
!!! !           !emom(1:3,ia,k)=m_j
!!! !           emomM(1:3,iia,k)=m_j*mmom(iia,k)
!!! !           do j=1,ham%nlistsize(iia)
!!! !              ja=ham%nlist(j,iia)
!!! !              srvec=coord(:,ja) -coord(:,countstart+1)
!!! !              m_j=0.0_dblprec
!!! !              do iq=1,nq
!!! !                 !
!!! !                 qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
!!! !                 m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
!!! !                 !
!!! !              end do
!!! !              call normalize(m_j)
!!! !              m_j=m_j*mmom(ja,k)
!!! !              emomM(1:3,ja,k)=m_j
!!! !              !
!!! !           end do
!!! !        end do
!!!          !  do ia=1,NA
!!!          !     iia=ia+countstart
!!!          !     m_i=0.0_dblprec
!!!          !     do iq=1,nq
!!!          !        qr=q(1,iq)*(coord(1,iia)-coord(1,countstart+1))+q(2,iq)*(coord(2,iia)-coord(2,countstart+1))+q(3,iq)*(coord(3,iia)-coord(3,countstart+1))
!!!          !        !
!!!          !        r_i=n_vec*cos(2.0_dblprec*pi*qr+phi(iq))+s(:,iq)*sin(2.0_dblprec*pi*qr+phi(iq))
!!!          !        m_i=m_i+r_i
!!!          !        !
!!!          !     end do
!!!          !     call normalize(m_i)
!!!          !     m_i=m_i*mmom(iia,k)
!!!          !     !
!!!          !     emomM(1:3,iia,k)=m_i
!!!          !     do j=1,ham%nlistsize(iia)
!!!          !        ja=ham%nlist(j,iia)
!!!          !        m_j=0.0_dblprec
!!!          !        do iq=1,nq
!!!          !           qr=q(1,iq)*(coord(1,ja)-coord(1,countstart+1))+q(2,iq)*(coord(2,ja)-coord(2,countstart+1))+q(3,iq)*(coord(3,ja)-coord(3,countstart+1))
!!!          !           !
!!!          !           r_j=n_vec*cos(2.0_dblprec*pi*qr+phi(iq))+s(:,iq)*sin(2.0_dblprec*pi*qr+phi(iq))
!!!          !           m_j=m_j+r_j
!!!          !           !
!!!          !        end do
!!!          !        call normalize(m_j)
!!!          !        m_j=m_j*mmom(ja,k)
!!!          !        emomM(1:3,ja,k)=m_j
!!!          !        !
!!!          !     end do
!!!                ! Calculate energy for given q,s,theta combination
!!!                call effective_field(Natom,Mensemble,countstart+1,countstart+na,         &
!!!                   do_jtensor,do_anisotropy,exc_inter,do_dm,do_pd,do_biqdm,do_bq,do_chir,&
!!!                   do_dip,emomM,mmom,external_field,time_external_field,beff,beff1,      &
!!!                   beff2,OPT_flag,max_no_constellations,maxNoConstl,unitCellType,        &
!!!                   constlNCoup,constellations,constellationsNeighType,mult_axis,         &
!!!                   energy,Num_macro,cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)
!!!                ! Anisotropy + external field to be added
!!! 
!!! !           end do
!!!          end do
!!!          energy=energy/mry*mub/NA/4
!!!          write(2000,'(i8,g20.8,g20.8)') iter,q(1,1),energy
!!!          ! Store best energy configuration if trial energy is lower than minimum
!!!          if(energy<min_energy) then
!!!             do iq=1,nq
!!!                write(*,'(i9,a,3f12.6,a,f8.3,a,f8.3,a,f8.3,a,2g14.7)',advance="yes")   &
!!!                   iter,'  New Q: ',q(:,iq),'  Theta: ',theta(iq)/pi*180, '  Phi: ',phi(iq)/pi*180, &
!!!                   ' Cone angle: ',cone_ang,'  dE: ',energy-min_energy, energy
!!!             end do
!!! 
!!!             min_energy=energy
!!!             q_best=q
!!!             theta_best=theta
!!!             theta_glob_best=theta_glob
!!!             phi_best=phi
!!!             lhit=iter
!!!             nhits=nhits+1
!!! 
!!!             write(200,'(i8,f18.8,3f14.6,20f14.6)') iter,energy,q, theta/pi*180,theta_glob/pi*180
!!! 
!!!             ! Restore previous configuration
!!!             q=q_save
!!!             s=s_save
!!!             theta=theta_save
!!!             theta_glob=theta_glob_save
!!!             phi=phi_save
!!!             cone_ang=cone_ang_save
!!! 
!!!          end if
!!!          ! Reduce range for global search
!!!          q_range=q_range0*(1.0_dblprec/iter**0.5)
!!!          theta_glob_range=theta_glob_range0*(1.0_dblprec/iter**0.5)
!!!       end do
!!!       !
!!!       !
!!!       print '(1x,a,i6,a)','Stochastic minimization done with ',nhits,' hits.'
!!!       print '(1x,a)','--------Energy---------|------------Q-and-S-vectors------------------|-------Theta-----'
!!!       do iq=1,nq
!!!          print '(2x,f18.10,2x,3f14.6,2x,2f18.6)',min_energy,q_best(:,iq), theta_best(iq)/pi*180,phi_best(iq)/pi*180
!!!          print '(2x,f18.10,2x,3f14.6,2x,2f18.6)',min_energy,s(:,iq), cone_ang     ,phi_best(iq)/pi*180
!!!          print '(1x,a)','-----------------------|---------------------------------------------|-----------------'
!!!       end do
!!!       q=q_best
!!!       !q=q_norm*0.05000_dblprec
!!!       print '(1x,a)','-----------------------|---------------------------------------------|-----------------'
!!!       !
!!!       !
!!!       return
!!!       !
!!!    end subroutine mini_q
!!! 
!!!    !-----------------------------------------------------------------------------
!!!    ! SUBROUTINE: sweep_q
!!!    !> @brief Stupid line search minimization of spin spirals
!!!    !> @author Anders Bergman
!!!    !-----------------------------------------------------------------------------
!!!    subroutine sweep_q(Natom,Mensemble,NA,coord,do_jtensor,exc_inter,do_dm,do_pd,     &
!!!       do_biqdm,do_bq,do_chir,taniso,sb,do_dip,emomM,mmom,hfield,OPT_flag,           &
!!!       max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
!!!       constellationsNeighType,mult_axis,Num_macro,cell_index,emomM_macro,           &
!!!       macro_nlistsize,do_anisotropy,simid)
!!! 
!!!       use RandomNumbers, only: rng_uniform,rng_gaussian, use_vsl
!!!       use Constants, only : mub, mry
!!!       use InputData, only : N1,N2,N3
!!!       use AMS, only : wrap_coord_diff
!!!       !
!!!       !.. Implicit declarations
!!!       implicit none
!!! 
!!!       integer, intent(in) :: Natom !< Number of atoms in system
!!!       integer, intent(in) :: Mensemble !< Number of ensembles
!!!       integer, intent(in) :: NA  !< Number of atoms in one cell
!!!       real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
!!!       integer, intent(in) :: do_jtensor   !<  Use SKKR style exchange tensor (0=off, 1=on, 2=with biquadratic exchange)
!!!       character(len=1),intent(in) :: exc_inter !< Interpolate Jij (Y/N)
!!!       integer, intent(in) :: do_dm   !< Add Dzyaloshinskii-Moriya (DM) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_pd   !< Add Pseudo-Dipolar (PD) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_biqdm   !< Add Biquadratic DM (BIQDM) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_bq   !< Add biquadratic exchange (BQ) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_chir  !< Add scalar chirality exchange (CHIR) term to Hamiltonian (0/1)
!!!       integer, intent(in) :: do_dip  !<  Calculate dipole-dipole contribution (0/1)
!!!       integer, intent(in) :: do_anisotropy
!!!       integer, dimension(Natom),intent(in) :: taniso !< Type of anisotropy (0-2)
!!!       real(dblprec), dimension(Natom),intent(in) :: sb !< Ratio between the anisotropies
!!!       real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
!!!       real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
!!!       real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
!!!       character(len=1), intent(in) :: mult_axis
!!!       !! +++ New variables due to optimization routines +++ !!
!!!       integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
!!!       ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
!!!       integer, dimension(Mensemble), intent(in) :: maxNoConstl
!!!       ! See OptimizationRoutines.f90 for details on classification
!!!       integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
!!!       ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
!!!       real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
!!!       ! Matrix storing all unit cells belonging to any constellation
!!!       real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
!!!       ! Optimization flag (1 = optimization on; 0 = optimization off)
!!!       logical, intent(in) :: OPT_flag
!!!       ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
!!!       ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
!!!       integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
!!!       ! Internal effective field arising from the optimization of the Heissenberg exchange term
!!!       integer, intent(in) :: Num_macro !< Number of macrocells in the system
!!!       integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
!!!       integer, dimension(Num_macro), intent(in) :: macro_nlistsize !< Number of atoms per macrocell
!!!       real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
!!!       character(len=8), intent(in) :: simid  !< Name of simulation
!!!       !
!!!       integer :: iq
!!!       !
!!!       real(dblprec), dimension(3) :: m_i, m_j, r_i, r_j, m_avg
!!!       real(dblprec) :: pi, qr, rx,ry, rz
!!!       integer :: i,j, k, iia, ia, ja, lhit, nhits, countstart
!!!       real(dblprec) :: energy, min_energy
!!!       character(len=30) :: filn
!!!       !
!!!       real(dblprec), dimension(3,3) :: q_best, q_diff, s_diff, q_0, s_0, q_norm
!!!       real(dblprec), dimension(3,3) :: s_save, q_save
!!!       real(dblprec), dimension(3) :: theta_save, theta_diff, theta_best
!!!       real(dblprec) :: theta_glob_save, cone_ang, cone_ang_save
!!!       real(dblprec) :: theta_glob_diff, theta_glob_best
!!!       real(dblprec), dimension(3) :: phi_save, phi_diff, phi_best
!!!       real(dblprec), dimension(1) :: cone_ang_diff
!!!       real(dblprec), dimension(1) :: rng_tmp_arr
!!!       integer :: iter, iscale, i1 ,i2 ,i3
!!!       real(dblprec) :: q_range, theta_range, s_range, phi_range, theta_glob_range, cone_ang_range
!!!       real(dblprec) :: q_range0, theta_range0, s_range0, phi_range0, theta_glob_range0
!!!       real(dblprec), dimension(3) :: srvec 
!!!       !
!!!       !
!!!       real(dblprec) :: q_start=1.0_dblprec
!!!       !
!!!       !
!!!       pi=4._dblprec*ATAN(1._dblprec)
!!!       theta_glob_best=0.0_dblprec
!!!       theta_best=0.0_dblprec
!!!       phi_best=0.0_dblprec
!!!       !
!!!       ! Normal vector
!!!       ! Read from file or default
!!!       !n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec;
!!!       !
!!!       ! Starting atom
!!!       I1 = N1/2
!!!       I2 = N2/2
!!!       I3 = N3/2
!!! 
!!!       countstart = 0+I1*NA+I2*N1*NA+I3*N2*N1*NA
!!!       !
!!!       write(filn,'(''qm_sweep.'',a,''.out'')') trim(simid)
!!!       open(ofileno,file=filn, position="append")
!!!       write(ofileno,'(a)') "#    Iter                          Q-vector                                 Energy  "
!!! 
!!!       write(filn,'(''qm_minima.'',a,''.out'')') trim(simid)
!!!       open(ofileno2,file=filn, position="append")
!!!       write(ofileno2,'(a)') "#    Iter                          Q-vector                                 Energy  "
!!!       ! Read from ip_mcnstep
!!!       !niter=10000
!!!       ! Hard wired to planar spin spirals with 360/nq degree angle inbetween
!!!       !
!!!       theta = 0.0_dblprec
!!!       theta_glob = 0.0_dblprec
!!!       !theta_glob = pi/4.0_dblprec
!!!       phi = 0.0_dblprec
!!!       ! NQ=1 for now
!!!       do iq=1,nq
!!! 
!!!          ! Q read from file or default
!!!          !q(1,iq)=1.0_dblprec;q(2,iq)=0.0_dblprec;q(3,iq)=0.0_dblprec
!!!          !! Start along [100] direction
!!!          call normalize(q(1:3,iq))
!!!          !
!!!          q_norm(:,iq)=q(:,iq) !/sqrt(sum(q(:,iq)*q(:,iq))+1.0e-12_dblprec)
!!!          !
!!!          if(norm2(s(:,iq))==0.0_dblprec) then
!!!             ! Create pitch vectors perpendicular to q and n
!!!             s(1,iq)=q_norm(2,iq)*n_vec(3)-q_norm(3,iq)*n_vec(2)
!!!             s(2,iq)=q_norm(3,iq)*n_vec(1)-q_norm(1,iq)*n_vec(3)
!!!             s(3,iq)=q_norm(1,iq)*n_vec(2)-q_norm(2,iq)*n_vec(1)
!!!          end if
!!!          call normalize(s(1:3,iq))
!!!          !
!!!          print *,'----Q-and-S-vectors----',iq
!!!          print '(3f10.4)', q(:,iq)
!!!          print '(3f10.4)', s(:,iq)
!!!          print '(3f10.4)', n_vec(:)
!!!          !
!!!          ! Currently hard wired starting guess (q_start from file or default)
!!!          !q(:,iq)=q(:,iq)/sqrt(sum(q(:,iq)*q(:,iq))) *q_start  !/30.0_dblprec
!!!       end do
!!!       !
!!!       !For Neel spirals:
!!!       !s=q_norm
!!!       !do iq=1,nq
!!!       !   print *,'----Q_0 vector----',iq
!!!       !   print '(3f10.4)', q_0(:,iq)
!!!       !end do
!!!       q_0=q
!!!       s_0=s
!!!       q_scale=(q_max-q_min)/(1.0_dblprec*nstep)
!!!       min_energy=1.0d4
!!!       !
!!!       lhit=0
!!!       nhits=0
!!!       iscale=1
!!! 
!!!       ! Switch rotation direction
!!! 
!!!       ! Calculate total external field (not included yet)
!!!       do k=1,Mensemble
!!!          do i=1,Natom
!!!             external_field(1:3,i,k)= hfield
!!!             beff(1:3,i,k)=0.0_dblprec
!!!             beff1(1:3,i,k)=0.0_dblprec
!!!             beff2(1:3,i,k)=0.0_dblprec
!!!          end do
!!!       end do
!!! 
!!!       ! Only use first ensemble
!!!       k=1
!!!       do iter=0,nstep
!!!          !print *,'------------------'
!!!          ! Loop over q
!!!          do iq=1,nq
!!!             !q(:,iq)=q_0(:,iq)-q_0(:,iq)/sqrt(sum(q_0(:,iq)**2))*(2.0_dblprec*q_start*iter)/(1.0_dblprec*niter)
!!!             q(:,iq)=q_norm(:,iq)*(q_min+q_scale*iter)
!!!          end do
!!!          !  print '(a,i7,3f12.6)', '--->',iter, q(:,1)
!!!          !         !
!!!          ! Set up spin-spiral magnetization (only first cell+ neighbours)
!!!          energy=0.0_dblprec
!!!          !!!print *,'----Q-and-S-vectors----',1
!!!          !!!print '(3f10.4)', q(:,1)
!!!          !!!print '(3f10.4)', s(:,1)
!!!          !!!print '(3f10.4)', n_vec(:)
!!!          !!!!stop
!!!          do ia=1,Natom
!!!             !
!!!             !srvec=coord(:,ia)-coord(:,countstart+1)
!!!             ! Possible use wrap_coord_diff() here.
!!!             call wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
!!!             !
!!!             m_j=0.0_dblprec
!!!             do iq=1,nq
!!!                qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
!!!                m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
!!!             end do
!!!             call normalize(m_j)
!!!             !emom(1:3,ia,k)=m_j
!!!             emomM(1:3,ia,k)=m_j*mmom(ia,k)
!!!             !print '(i7,3f12.6)', ia, emomM(1:3,ia,k)
!!! 
!!!          end do
!!!          ! Calculate energy for given q,s,theta combination
!!!          ! Anisotropy + external field to be added
!!!          call effective_field(Natom,Mensemble,countstart+1,countstart+na,         &
!!!             do_jtensor,do_anisotropy,exc_inter,do_dm,do_pd,do_biqdm,do_bq,do_chir,&
!!!             do_dip,emomM,mmom,external_field,time_external_field,beff,beff1,      &
!!!             beff2,OPT_flag,max_no_constellations,maxNoConstl,unitCellType,        &
!!!             constlNCoup,constellations,constellationsNeighType,mult_axis,         &
!!!             energy,Num_macro,cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)
!!! 
!!!          energy=energy/NA !/mry*mub/NA
!!! 
!!!          write(ofileno,'(i8,3g20.8,g20.8)') iter,q(:,1),energy
!!!          ! Store best energy configuration if trial energy is lower than minimum
!!!          if(energy<min_energy) then
!!!             !do iq=1,nq
!!!             !   write(*,'(i9,a,3f12.6,a,f8.3,a,f8.3,a,f8.3,a,2g14.7)',advance="yes")   &
!!!             !      iter,'  New Q: ',q(:,iq),'  Theta: ',theta(iq)/pi*180, '  Phi: ',phi(iq)/pi*180, &
!!!             !      ' Cone angle: ',cone_ang,'  dE: ',energy-min_energy, energy
!!!             !end do
!!! 
!!!             min_energy=energy
!!!             q_best=q
!!!             lhit=iter
!!!             nhits=nhits+1
!!! 
!!!             write(ofileno2,'(i8,3g20.8,g20.8)') iter,q(:,1),energy
!!! 
!!!          end if
!!!       end do
!!!       !
!!!       !
!!!       print '(1x,a,i6,a)','Line search minimization done with ',nhits,' hits.'
!!!       print '(1x,a)', '|-----Minimum energy----|----------------Q-vector-----------------|------------------S-vector----------------|'
!!!       do iq=1,nq
!!!          print '(2x,f18.10,2x,3f14.6,2x,3f14.6)',min_energy,q_best(:,iq),s(:,iq)
!!!       end do
!!!       ! Important: Save the lowest energy q-vector
!!!       q=q_best
!!!       print '(1x,a)','|-----------------------|-----------------------------------------|------------------------------------------|'
!!! 
!!!       !
!!!       close(ofileno)
!!!       close(ofileno2)
!!!       !
!!!       !
!!!       return
!!!       !
!!!    end subroutine sweep_q

   !-----------------------------------------------------------------------------
   ! SUBROUTINE: sweep_q2
   !> @brief Stupid line search minimization of spin spirals (clone of sweep_q
   !  but for external q-point set.
   !> @author Anders Bergman
   !-----------------------------------------------------------------------------
   subroutine sweep_q2(Natom,Mensemble,NA,coord,emomM,mmom,hfield,OPT_flag,           &
      max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
      constellationsNeighType,Num_macro,cell_index,emomM_macro,           &
      macro_nlistsize,simid,qpts,nq)

      use RandomNumbers, only: rng_uniform,rng_gaussian
      use InputData, only : N1,N2,N3
      use Math_functions, only : f_wrap_coord_diff, f_cross_product
      use Depondt, only : rodmat
      use Diamag, only : diamag_qvect
      !
      !.. Implicit declarations
      implicit none

      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      integer, intent(in) :: NA  !< Number of atoms in one cell
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
      !! +++ New variables due to optimization routines +++ !!
      integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
      ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
      integer, dimension(Mensemble), intent(in) :: maxNoConstl
      ! See OptimizationRoutines.f90 for details on classification
      integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
      ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
      real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
      ! Matrix storing all unit cells belonging to any constellation
      real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
      ! Optimization flag (1 = optimization on; 0 = optimization off)
      logical, intent(in) :: OPT_flag
      ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
      ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
      integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
      ! Internal effective field arising from the optimization of the Heissenberg exchange term
      integer, intent(in) :: Num_macro !< Number of macrocells in the system
      integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
      integer, dimension(Num_macro), intent(in) :: macro_nlistsize !< Number of atoms per macrocell
      real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
      character(len=8), intent(in) :: simid  !< Name of simulation
      integer, intent(in) :: nq  !< number of qpoints
      real(dblprec), dimension(3,nq), intent(in) :: qpts !< Array of q-points
      !
      integer :: iq
      !
      real(dblprec), dimension(3) :: m_j
      real(dblprec) :: pi, qr
      integer :: i, k, ia, lhit, nhits, countstart
      real(dblprec) :: energy, min_energy
      character(len=30) :: filn
      !
      real(dblprec), dimension(3,3) :: q_best
      real(dblprec), dimension(3,3) :: s_save
      real(dblprec), dimension(3) :: theta_best
      real(dblprec) :: theta_glob_best
      real(dblprec), dimension(3) :: phi_best
      integer :: iter, iscale, i1 ,i2 ,i3
      real(dblprec), dimension(3) :: srvec 
      real(dblprec), dimension(3,3) :: R_mat
      real(dblprec), dimension(:,:,:), allocatable :: emomM_start

      real(dblprec), dimension(3) :: mavg
      !
      integer :: i_stat, i_all
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      theta_glob_best=0.0_dblprec
      theta_best=0.0_dblprec
      phi_best=0.0_dblprec
      phi=0.0_dblprec
      !
      ! Normal vector
      ! Read from file or default
      !n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec;
      !
      ! Starting atom
      I1 = N1/2
      I2 = N2/2
      I3 = N3/2

      countstart = 0+I1*NA+I2*N1*NA+I3*N2*N1*NA
      !
      write(filn,'(''qm_sweep.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn, position="append")
      write(ofileno,'(a)') "#    Iter                          Q-vector                                 Energy(meV)  "

      write(filn,'(''qm_minima.'',a,''.out'')') trim(simid)
      open(ofileno2,file=filn, position="append")
      write(ofileno2,'(a)') "#    Iter                          Q-vector                                 Energy(mRy)  "
     
    
      if (qm_rot=='Y') then
         allocate(emomM_start(3,Natom,Mensemble),stat=i_stat)
         call memocc(i_stat,product(shape(emomM_start))*kind(emomM_start),'emomM_start','sweep_q2')
         emomM_start=emomM

         if (qm_oaxis=='Y') then
            mavg(1)=sum(emomM(1,:,:))/Natom/Mensemble
            mavg(2)=sum(emomM(2,:,:))/Natom/Mensemble
            mavg(3)=sum(emomM(3,:,:))/Natom/Mensemble
            mavg=mavg/(norm2(mavg)+1.0e-12_dblprec)
            if(abs(mavg(3)-1.0_dblprec)<1.0e-6_dblprec) then
               n_vec(1)=1.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=0.0_dblprec
            else
               n_vec(1)=mavg(1); n_vec(2)=-mavg(2); n_vec(3)=0.0_dblprec
            end if
            n_vec=n_vec/norm2(n_vec)
         end if

      end if
      
      !
      theta = 0.0_dblprec
      theta_glob = 0.0_dblprec
      phi = 0.0_dblprec
      min_energy=1.0d4

      !
      lhit=0
      nhits=0
      iscale=1

      ! Switch rotation direction

      ! Calculate total external field (not included yet)
      do k=1,Mensemble
         do i=1,Natom
            external_field(1:3,i,k)= hfield
            beff(1:3,i,k)=0.0_dblprec
            beff1(1:3,i,k)=0.0_dblprec
            beff2(1:3,i,k)=0.0_dblprec
         end do
      end do

      ! Only use first ensemble
      k=1
      do iq=1,nq
         iter=iq
         !         !
         ! Set up spin-spiral magnetization (only first cell+ neighbours)
         energy=0.0_dblprec
         ! Check if diamag_qvect and then only use that spin spiral vector
         if (norm2(diamag_qvect)>0.0_dblprec) then
            q(:,1)=diamag_qvect
         else
            q(:,1)=qpts(:,iq)
         end if
         !!! s(1,1)=q(2,1)*n_vec(3)-q(3,1)*n_vec(2)
         !!! s(2,1)=q(3,1)*n_vec(1)-q(1,1)*n_vec(3)
         !!! s(3,1)=q(1,1)*n_vec(2)-q(2,1)*n_vec(1)
         !!! if(norm2(s(:,1))<1.0e-12_dblprec) then
         !!!    !print '(a,3f12.6)','s before:',s
         !!!    s(1,1)=1.0_dblprec
         !!!    s(2,1)=0.0_dblprec
         !!!    s(3,1)=0.0_dblprec
         !!!    !print '(a,3f12.6)','s after:',s
         !!! end if
         !!! s(:,1)=s(:,1)/norm2(s(:,1))

         !!! print *,'----Q-and-S-vectors----',1
         !!! print '(3f10.4)', q(:,1)
         !!! print '(3f10.4)', s(:,1)
         !!! print '(3f10.4)', n_vec(:)


         !!!!stop
         ! Set up magnetic order 
         ! If qm_rot=Y, take the original magnetic order and rotate each spin to 
         ! create spin-spirals in an disordered background
         ! otherwise rotate all spins to create pure spin-spirals
         if (qm_rot=='Y') then
            do ia=1,Natom
               !
               call f_wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
               !
               qr=q(1,1)*srvec(1)+q(2,1)*srvec(2)+q(3,1)*srvec(3)
               !qr=qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3)
               qr=2.0_dblprec*pi*qr

               call rodmat(n_vec,qr,R_mat)

               emomM(1:3,ia,k)=matmul(R_mat,emomM_start(:,ia,k))
            end do
         else
            call set_nsvec(qm_type,q(:,1),s(:,1),n_vec)
            !call set_nsvec(qm_type,qpts(:,iq),s(:,1),n_vec)
            !!! print *,'IQ:',iq
            !!! print '(a,3f12.6)' , '   iq:', q(:,1)
            !!! !print '(a,3f12.6)' , '   iq:', qpts(:,iq)
            !!! print '(a,3f12.6)' , 's_vec:', s(:,1)
            !!! print '(a,3f12.6)' , 'n_vec:', n_vec
            !!! print '(a,3f12.6)' , 'cross:', f_cross_product(n_vec,s(:,1))

            do ia=1,Natom
               !
               !srvec=coord(:,ia)-coord(:,countstart+1)
               ! Possible use wrap_coord_diff() here.
               call f_wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
               !
               m_j=0.0_dblprec
               qr=q(1,1)*srvec(1)+q(2,1)*srvec(2)+q(3,1)*srvec(3)
               !qr=qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3)
               m_j=n_vec*cos(2*pi*qr+phi(1))+s(:,1)*sin(2*pi*qr+phi(1))
               !print '(a,4f12.6)' , 'r_i  :',qr,m_j
               !print '(a,4f12.6)' , 'qr,mj:',qr,m_j
               !call normalize(m_j)
               !emom(1:3,ia,k)=m_j
               emomM(1:3,ia,k)=m_j*mmom(ia,k)
               !print '(a,3f12.6,i8)' , 'emom :', emomM(1:3,ia,k), ia
               !print '(i7,3f12.6)', ia, emomM(1:3,ia,k)
            end do
         end if
         !!! if (qm_rot=='Y') then
         !!! else
         !!!    do ia=1,Natom
         !!!       !
         !!!       !srvec=coord(:,ia)-coord(:,countstart+1)
         !!!       ! Possible use wrap_coord_diff() here.
         !!!       call f_wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
         !!!       !
         !!!       m_j=0.0_dblprec
         !!!       qr=qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3)
         !!!       m_j=n_vec*cos(2*pi*qr+phi(1))+s(:,1)*sin(2*pi*qr+phi(1))
         !!!       !call normalize(m_j)
         !!!       !emom(1:3,ia,k)=m_j
         !!!       emomM(1:3,ia,k)=m_j*mmom(ia,k)
         !!!       !print '(i7,3f12.6)', ia, emomM(1:3,ia,k)
         !!!    end do
         !!! end if

         ! Calculate energy for given q,s,theta combination
         ! Anisotropy + external field to be added
         energy=0.0_dblprec
         !call effective_field(Natom,Mensemble,countstart+1,countstart+na,         &
         call effective_field(Natom,Mensemble,1,Natom, &
            emomM,mmom,external_field,time_external_field,beff,beff1,      &
            beff2,OPT_flag,max_no_constellations,maxNoConstl,unitCellType,        &
            constlNCoup,constellations,constellationsNeighType,         &
            energy,Num_macro,cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)

         energy=energy/Natom !/mub*mry !/mry*mub/NA
         !  print '(a,3f12.6)' , 'ene  :', energy

         call f_wrap_coord_diff(Natom,coord,countstart+1,countstart+1,srvec)
         !!! print '(3f10.4,5x,1f10.5,5x,3f10.4,5x,3f10.4,10x,f12.6)',qpts(:,iq),&
         !!!    srvec,&
         !!!    qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3),&
         !!!    emomM(:,countstart+1,1),energy

         write(ofileno,'(i8,3g20.8,g20.8)') iq,q(:,1),energy*13.605_dblprec !/mry*mub*13.605_dblprec
         !write(ofileno,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy*13.605_dblprec !/mry*mub*13.605_dblprec

         ! Store best energy configuration if trial energy is lower than minimum
         if(energy<min_energy) then

            min_energy=energy
            !q_best(:,1)=qpts(:,iq)
            q_best(:,1)=q(:,1)
            s_save(:,1)=s(:,1)
            lhit=iter
            nhits=nhits+1
            write(ofileno2,'(i8,3g20.8,g20.8)') iq,q(:,1),energy
            !write(ofileno2,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy

         end if
         ! Do not loop if diamag_qvect is set
         if (norm2(diamag_qvect)>0.0_dblprec) exit
      end do
      !
      !
      print '(1x,a,i6,a)','Line search minimization done with ',nhits,' hits.'
      print '(1x,a)', '|-----Minimum energy----|----------------Q-vector-----------------|------------------S-vector----------------|'
      do iq=1,1
         print '(2x,f18.10,2x,3f14.6,2x,3f14.6)',min_energy,q_best(:,iq),s(:,iq)
      end do
      ! Important: Save the lowest energy q-vector
      q=q_best
      ! Save best q_vector for nc-AMS
      if (norm2(diamag_qvect)==0.0_dblprec) diamag_qvect = q_best(:,1)
      s=s_save
      print '(1x,a)','|-----------------------|-----------------------------------------|------------------------------------------|'

      !
      close(ofileno)
      close(ofileno2)
      !
      if (qm_rot=='Y') then
         i_all=-product(shape(emomM_start))*kind(emomM_start)
         deallocate(emomM_start,stat=i_stat)
         call memocc(i_stat,i_all,'emomM_start','emomM_start')
      end if
      !
      return
      !
   end subroutine sweep_q2


   !-----------------------------------------------------------------------------
   ! SUBROUTINE: sweep_q3
   !> @brief Stupid line search minimization of spin spirals (clone of sweep_q
   !  but for external q-point set.
   !> @author Anders Bergman
   !-----------------------------------------------------------------------------
   subroutine sweep_q3(Natom,Mensemble,NA,coord,emomM,mmom,hfield,OPT_flag,           &
      max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
      constellationsNeighType,Num_macro,cell_index,emomM_macro,           &
      macro_nlistsize,simid,qpts,nq)

      use RandomNumbers, only: rng_uniform,rng_gaussian
      use InputData, only : N1,N2,N3
      use Math_functions, only : f_wrap_coord_diff
      use Depondt, only : rodmat
      !
      !.. Implicit declarations
      implicit none

      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      integer, intent(in) :: NA  !< Number of atoms in one cell
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
      !! +++ New variables due to optimization routines +++ !!
      integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
      ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
      integer, dimension(Mensemble), intent(in) :: maxNoConstl
      ! See OptimizationRoutines.f90 for details on classification
      integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
      ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
      real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
      ! Matrix storing all unit cells belonging to any constellation
      real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
      ! Optimization flag (1 = optimization on; 0 = optimization off)
      logical, intent(in) :: OPT_flag
      ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
      ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
      integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
      ! Internal effective field arising from the optimization of the Heissenberg exchange term
      integer, intent(in) :: Num_macro !< Number of macrocells in the system
      integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
      integer, dimension(Num_macro), intent(in) :: macro_nlistsize !< Number of atoms per macrocell
      real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
      character(len=8), intent(in) :: simid  !< Name of simulation
      integer, intent(in) :: nq  !< number of qpoints
      real(dblprec), dimension(3,nq), intent(in) :: qpts !< Array of q-points
      !
      integer :: iq
      !
      real(dblprec), dimension(3) :: m_j
      real(dblprec) :: pi, qr
      integer :: i, k, ia, lhit, nhits, countstart
      real(dblprec) :: energy, min_energy
      character(len=30) :: filn
      !
      real(dblprec), dimension(3,3) :: q_best
      real(dblprec), dimension(3,3) :: R_mat
      real(dblprec), dimension(3) :: theta_best
      real(dblprec) :: theta_glob_best
      real(dblprec), dimension(3) :: phi_best
      integer :: iter, iscale, i1 ,i2 ,i3, qq
      real(dblprec), dimension(3) :: srvec 
      !
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      theta_glob_best=0.0_dblprec
      theta_best=0.0_dblprec
      phi_best=0.0_dblprec
      phi=0.0_dblprec
      !
      ! Normal vector
      ! Read from file or default
      !n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec;
      !
      ! Starting atom
      I1 = N1/2
      I2 = N2/2
      I3 = N3/2

      countstart = 0+I1*NA+I2*N1*NA+I3*N2*N1*NA
      !
      write(filn,'(''qm_sweep.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn, position="append")
      write(ofileno,'(a)') "#    Iter                          Q-vector                                 Energy(meV)  "

      write(filn,'(''qm_minima.'',a,''.out'')') trim(simid)
      open(ofileno2,file=filn, position="append")
      write(ofileno2,'(a)') "#    Iter                          Q-vector                                 Energy(mRy)  "
     
    
      
      !
      theta = 0.0_dblprec
      theta_glob = 0.0_dblprec
      phi = 0.0_dblprec
      min_energy=1.0d4

      !
      lhit=0
      nhits=0
      iscale=1

      ! Switch rotation direction

      ! Calculate total external field (not included yet)
      do k=1,Mensemble
         do i=1,Natom
            external_field(1:3,i,k)= hfield
            beff(1:3,i,k)=0.0_dblprec
            beff1(1:3,i,k)=0.0_dblprec
            beff2(1:3,i,k)=0.0_dblprec
         end do
      end do

      ! Only use first ensemble
      k=1
      do iq=1,nq
         iter=iq
         !         !
         ! Set up spin-spiral magnetization (only first cell+ neighbours)
         energy=0.0_dblprec
         !!!print *,'----Q-and-S-vectors----',1
         !!!print '(3f10.4)', q(:,1)
         !!!print '(3f10.4)', s(:,1)
         !!!print '(3f10.4)', n_vec(:)
         q(:,1)=qpts(:,iq)
         ! Rotate 360/iq
         theta(1)=0.0d0
         theta(2)=2.0_dblprec*pi/3.0d0*(1.0_dblprec)
         theta(3)=2.0_dblprec*pi/3.0d0*(2.0_dblprec)
         ! Replace with Rodrigues

         do qq=2,3
            !!! rx= q(1,1)*cos(theta(qq))+q(2,1)*sin(theta(qq))
            !!! ry=-q(1,1)*sin(theta(qq))+q(2,1)*cos(theta(qq))
            !!! q(1,qq)=rx
            !!! q(2,qq)=ry
            !!! q(3,qq)=0.0_dblprec
            !!! rx= s(1,1)*cos(theta(qq))+s(2,1)*sin(theta(qq))
            !!! ry=-s(1,1)*sin(theta(qq))+s(2,1)*cos(theta(qq))
            !!! s(1,qq)=rx
            !!! s(2,qq)=ry
            call rodmat(n_vec,theta(qq),R_mat)
            q(:,qq)=matmul(R_mat,q(:,1))
            s(:,qq)=matmul(R_mat,s(:,1))
            !s(:,qq)=s(:,1)
         end do
         !!!!stop
         !!! print *,'----Q-and-S-vectors----',1
         !!! print '(3f10.4)', q(:,1)
         !!! print '(3f10.4)', s(:,1)
         !!! print '(3f10.4)', n_vec(:)
         !!! print *,'----Q-and-S-vectors----',2
         !!! print '(3f10.4)', q(:,2)
         !!! print '(3f10.4)', s(:,2)
         !!! print '(3f10.4)', n_vec(:)
         !!! print *,'----Q-and-S-vectors----',3
         !!! print '(3f10.4)', q(:,3)
         !!! print '(3f10.4)', s(:,3)
         !!! print '(3f10.4)', n_vec(:)
         do ia=1,Natom
            !
            !srvec=coord(:,ia)-coord(:,countstart+1)
            ! Possible use wrap_coord_diff() here.
            call f_wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
            !
            m_j=0.0_dblprec
            do qq=1,3
               !qr=qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3)
               qr=q(1,qq)*srvec(1)+q(2,qq)*srvec(2)+q(3,qq)*srvec(3)
               m_j=m_j+n_vec*cos(2*pi*qr)+s(:,qq)*sin(2*pi*qr)
               !m_j=m_j+n_vec*cos(2*pi*qr+phi(1))+s(:,qq)*sin(2*pi*qr+phi(1))
            end do
            call normalize(m_j)
            !emom(1:3,ia,k)=m_j
            emomM(1:3,ia,k)=m_j*mmom(ia,k)
            !print '(i7,3f12.6)', ia, emomM(1:3,ia,k)
         end do

         ! Calculate energy for given q,s,theta combination
         ! Anisotropy + external field to be added
         energy=0.0_dblprec
         !call effective_field(Natom,Mensemble,countstart+1,countstart+na,         &
         call effective_field(Natom,Mensemble,1,Natom, &
            emomM,mmom,external_field,time_external_field,beff,beff1,      &
            beff2,OPT_flag,max_no_constellations,maxNoConstl,unitCellType,        &
            constlNCoup,constellations,constellationsNeighType,         &
            energy,Num_macro,cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)

         energy=energy/Natom !/mub*mry !/mry*mub/NA

         call f_wrap_coord_diff(Natom,coord,countstart+1,countstart+1,srvec)
         !!! print '(3f10.4,5x,1f10.5,5x,3f10.4,5x,3f10.4,10x,f12.6)',qpts(:,iq),&
         !!!    srvec,&
         !!!    qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3),&
         !!!    emomM(:,countstart+1,1),energy

         write(ofileno,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy*13.605_dblprec !/mry*mub*13.605_dblprec

         ! Store best energy configuration if trial energy is lower than minimum
         if(energy<min_energy) then

            min_energy=energy
            !q_best(:,1)=qpts(:,iq)
            q_best=q
            lhit=iter
            nhits=nhits+1
            write(ofileno2,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy

         end if
      end do
      !
      !
      print '(1x,a,i6,a)','Line search minimization done with ',nhits,' hits.'
      print '(1x,a)', '|-----Minimum energy----|----------------Q-vector-----------------|------------------S-vector----------------|'
      do iq=1,3
         print '(2x,f18.10,2x,3f14.6,2x,3f14.6)',min_energy,q_best(:,iq),s(:,iq)
      end do
      ! Important: Save the lowest energy q-vector
      q=q_best
      !s=s_save
      print '(1x,a)','|-----------------------|-----------------------------------------|------------------------------------------|'

      !
      close(ofileno)
      close(ofileno2)
      !
      !
      return
      !
   end subroutine sweep_q3

   !-----------------------------------------------------------------------------
   ! SUBROUTINE: sweep_q3
   !> @brief Stupid line search minimization of spin spirals (clone of sweep_q
   !  but for external q-point set.
   !> @author Anders Bergman
   !-----------------------------------------------------------------------------
   subroutine sweep_cube(Natom,Mensemble,NA,coord,emomM,mmom,hfield,OPT_flag,           &
      max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
      constellationsNeighType,Num_macro,cell_index,emomM_macro,           &
      macro_nlistsize,simid,qpts,nq)

      use RandomNumbers, only: rng_uniform,rng_gaussian
      use InputData, only : N1,N2,N3
      use Math_functions, only : f_wrap_coord_diff
      !
      !.. Implicit declarations
      implicit none

      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      integer, intent(in) :: NA  !< Number of atoms in one cell
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
      !! +++ New variables due to optimization routines +++ !!
      integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
      ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
      integer, dimension(Mensemble), intent(in) :: maxNoConstl
      ! See OptimizationRoutines.f90 for details on classification
      integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
      ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
      real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
      ! Matrix storing all unit cells belonging to any constellation
      real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
      ! Optimization flag (1 = optimization on; 0 = optimization off)
      logical, intent(in) :: OPT_flag
      ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
      ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
      integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
      ! Internal effective field arising from the optimization of the Heissenberg exchange term
      integer, intent(in) :: Num_macro !< Number of macrocells in the system
      integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
      integer, dimension(Num_macro), intent(in) :: macro_nlistsize !< Number of atoms per macrocell
      real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
      character(len=8), intent(in) :: simid  !< Name of simulation
      integer, intent(in) :: nq  !< number of qpoints
      real(dblprec), dimension(3,nq), intent(in) :: qpts !< Array of q-points
      !
      integer :: iq, jq
      !
      real(dblprec), dimension(3) :: m_j
      real(dblprec) :: pi, qr
      integer :: i, k, ia, lhit, nhits, countstart
      real(dblprec) :: energy, min_energy
      character(len=30) :: filn
      !
      real(dblprec), dimension(3,3) :: q_best
      real(dblprec), dimension(3,3) :: s_save
      real(dblprec), dimension(3) :: theta_best
      real(dblprec) :: theta_glob_best
      real(dblprec), dimension(3) :: phi_best
      integer :: iter, iscale, i1 ,i2 ,i3, qq
      real(dblprec), dimension(3) :: srvec 
      !
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      theta_glob_best=0.0_dblprec
      theta_best=0.0_dblprec
      phi_best=0.0_dblprec
      phi=0.0_dblprec
      !
      ! Normal vector
      ! Read from file or default
      !n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec;
      !
      ! Starting atom
      I1 = N1/2
      I2 = N2/2
      I3 = N3/2

      countstart = 0+I1*NA+I2*N1*NA+I3*N2*N1*NA
      !
      write(filn,'(''qm_sweep.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn, position="append")
      write(ofileno,'(a)') "#    Iter                          Q-vector                                 Energy(meV)  "

      write(filn,'(''qm_minima.'',a,''.out'')') trim(simid)
      open(ofileno2,file=filn, position="append")
      write(ofileno2,'(a)') "#    Iter                          Q-vector                                 Energy(mRy)  "
     
    
      
      !
      theta = 0.0_dblprec
      theta_glob = 0.0_dblprec
      phi = 0.0_dblprec
      min_energy=1.0d4

      !
      lhit=0
      nhits=0
      iscale=1

      ! Switch rotation direction

      ! Calculate total external field (not included yet)
      do k=1,Mensemble
         do i=1,Natom
            external_field(1:3,i,k)= hfield
            beff(1:3,i,k)=0.0_dblprec
            beff1(1:3,i,k)=0.0_dblprec
            beff2(1:3,i,k)=0.0_dblprec
         end do
      end do

      ! Only use first ensemble
      k=1
      ! Hand hacked pitch/normal vectors
      q=0.0d0
      n_vec(1)=0.0d0
      n_vec(2)=0.0d0
      n_vec(3)=1.0d0
      do iq=1,1
         iter=iq
         !         !
         do jq=2, 2
            ! Set up spin-spiral magnetization (only first cell+ neighbours)
            energy=0.0_dblprec
            !!!print *,'----Q-and-S-vectors----',1
            !!!print '(3f10.4)', q(:,1)
            !!!print '(3f10.4)', s(:,1)
            !!!print '(3f10.4)', n_vec(:)
            q(:,1)=qpts(:,iq)
            q(:,2)=qpts(:,jq)

            s(1,1)=q(2,1)*n_vec(3)-q(3,1)*n_vec(2)
            s(2,1)=q(3,1)*n_vec(1)-q(1,1)*n_vec(3)
            s(3,1)=q(1,1)*n_vec(2)-q(2,1)*n_vec(1)
            s(:,1)=s(:,1)/norm2(s(:,1))

            s(1,2)=q(2,2)*n_vec(3)-q(3,2)*n_vec(2)
            s(2,2)=q(3,2)*n_vec(1)-q(1,2)*n_vec(3)
            s(3,2)=q(1,2)*n_vec(2)-q(2,2)*n_vec(1)
            s(:,2)=s(:,2)/norm2(s(:,2))
            !!! ! Rotate 360/iq
            !!! theta(1)=0.0d0
            !!! theta(2)=2.0_dblprec*pi/3.0d0*(1.0_dblprec)
            !!! theta(3)=2.0_dblprec*pi/3.0d0*(2.0_dblprec)
            !!! do qq=2,3
            !!!    rx= q(1,1)*cos(theta(qq))+q(2,1)*sin(theta(qq))
            !!!    ry=-q(1,1)*sin(theta(qq))+q(2,1)*cos(theta(qq))
            !!!    q(1,qq)=rx
            !!!    q(2,qq)=ry
            !!!    q(3,qq)=0.0_dblprec
            !!!    rx= s(1,1)*cos(theta(qq))+s(2,1)*sin(theta(qq))
            !!!    ry=-s(1,1)*sin(theta(qq))+s(2,1)*cos(theta(qq))
            !!!    s(1,qq)=rx
            !!!    s(2,qq)=ry
            !!!    !s(:,qq)=s(:,1)
            !!! end do
            !!!!stop
            print *,'----Q-and-S-vectors----',1
            print '(3f10.4)', q(:,1)
            print '(3f10.4)', s(:,1)
            print '(3f10.4)', n_vec(:)
            print *,'----Q-and-S-vectors----',2
            print '(3f10.4)', q(:,2)
            print '(3f10.4)', s(:,2)
            print '(3f10.4)', n_vec(:)
            !!! print *,'----Q-and-S-vectors----',3
            !!! print '(3f10.4)', q(:,3)
            !!! print '(3f10.4)', s(:,3)
            !!! print '(3f10.4)', n_vec(:)
            do ia=1,Natom
               !
               !srvec=coord(:,ia)-coord(:,countstart+1)
               ! Possible use wrap_coord_diff() here.
               call f_wrap_coord_diff(Natom,coord,ia,countstart+1,srvec)
               !
               m_j=0.0_dblprec
               do qq=1,2
                  !qr=qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3)
                  qr=q(1,qq)*srvec(1)+q(2,qq)*srvec(2)+q(3,qq)*srvec(3)
                  m_j=m_j+n_vec*cos(2*pi*qr)+s(:,qq)*sin(2*pi*qr)
                  !m_j=m_j+n_vec*cos(2*pi*qr+phi(1))+s(:,qq)*sin(2*pi*qr+phi(1))
               end do
               call normalize(m_j)
               !emom(1:3,ia,k)=m_j
               emomM(1:3,ia,k)=m_j*mmom(ia,k)
               !print '(i7,3f12.6)', ia, emomM(1:3,ia,k)
            end do

            ! Calculate energy for given q,s,theta combination
            ! Anisotropy + external field to be added
            energy=0.0_dblprec
            !call effective_field(Natom,Mensemble,countstart+1,countstart+na,         &
            call effective_field(Natom,Mensemble,1,Natom, &
               emomM,mmom,external_field,time_external_field,beff,beff1,      &
               beff2,OPT_flag,max_no_constellations,maxNoConstl,unitCellType,        &
               constlNCoup,constellations,constellationsNeighType,         &
               energy,Num_macro,cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)

            energy=energy/Natom !/mub*mry !/mry*mub/NA

            call f_wrap_coord_diff(Natom,coord,countstart+1,countstart+1,srvec)
            !!! print '(3f10.4,5x,1f10.5,5x,3f10.4,5x,3f10.4,10x,f12.6)',qpts(:,iq),&
            !!!    srvec,&
            !!!    qpts(1,iq)*srvec(1)+qpts(2,iq)*srvec(2)+qpts(3,iq)*srvec(3),&
            !!!    emomM(:,countstart+1,1),energy

            write(ofileno,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy*13.605_dblprec !/mry*mub*13.605_dblprec

            ! Store best energy configuration if trial energy is lower than minimum
            if(energy<min_energy) then

               min_energy=energy
               !q_best(:,1)=qpts(:,iq)
               q_best=q
               s_save=s
               lhit=iter
               nhits=nhits+1
               write(ofileno2,'(i8,3g20.8,g20.8)') iq,qpts(:,iq),energy
               write(ofileno2,'(i8,3g20.8,g20.8)') jq,qpts(:,jq),energy

            end if
         end do
      end do
      !
      !
      print '(1x,a,i6,a)','Line search minimization done with ',nhits,' hits.'
      print '(1x,a)', '|-----Minimum energy----|----------------Q-vector-----------------|------------------S-vector----------------|'
      do iq=1,2
         print '(2x,f18.10,2x,3f14.6,2x,3f14.6)',min_energy,q_best(:,iq),s(:,iq)
      end do
      ! Important: Save the lowest energy q-vector
      q=q_best
      s=s_save
      print '(1x,a)','|-----------------------|-----------------------------------------|------------------------------------------|'

      !
      close(ofileno)
      close(ofileno2)
      !
      !
      return
      !
   end subroutine sweep_cube

   !> Plot final configuration
   subroutine plot_q(Natom, Mensemble, coord, emom, emomM, mmom,simid)
      !
      use math_functions, only : f_wrap_coord_diff
      implicit none
      !
      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emom  !< Current magnetic moment vector
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      character(len=8), intent(in) :: simid  !< Name of simulation
      !
      real(dblprec), dimension(3) :: srvec, m_j
      integer :: lhit, ia, k, iq
      real(dblprec) :: pi, qr
      character(len=30) :: filn
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      !
      !nplot=12
      !q=10.0_dblprec*q
      !
      write(filn,'(''qm_restart.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn)
      !write(ofileno,*) 0
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a,1x,a)') "# File type:", 'R'
      write(ofileno,'(a,1x,a)') "# Simulation type:", 'Q'
      write(ofileno,'(a,1x,i8)')"# Number of atoms: ", Natom
      write(ofileno,'(a,1x,i8)')"# Number of ensembles: ", Mensemble
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a8,a,a8,a16,a16,a16,a16)') "#Timestep","ens","iatom","|Mom|","M_x","M_y","M_z"
      do k=1,Mensemble
         do ia=1,Natom
            lhit=lhit+1
            !srvec=coord(:,ia)
            call f_wrap_coord_diff(Natom,coord,ia,1,srvec)
            !
            m_j=0.0_dblprec
            do iq=1,1!nq
               call set_nsvec(qm_type,q(:,iq),s(:,iq),n_vec)
               qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
               m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
            end do
            call normalize(m_j)
            emom(1:3,ia,k)=m_j
            emomM(1:3,ia,k)=m_j*mmom(ia,k)
            !write(ofileno,'(2i8,4f14.6)') 1,lhit,mmom(ia,k),m_j
            !write(ofileno,'(2i8,4f14.6)') 1,ia,mmom(ia,k),m_j
            write(ofileno,10003) 0,1,ia,mmom(ia,k),m_j
         end do
      end do
      close(ofileno)
      !
      10003 format(i8,i8,i8,2x,es16.8,es16.8,es16.8,es16.8)
      !10003 format(es16.8,i8,i8,2x,es16.8,es16.8,es16.8,es16.8)
      !
      !
   end subroutine plot_q


   !> Plot final configuration
   subroutine plot_q3(Natom, Mensemble, coord, emom, emomM, mmom,simid)
      use Math_functions, only : f_wrap_coord_diff
      !
      implicit none
      !
      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emom  !< Current magnetic moment vector
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      character(len=8), intent(in) :: simid  !< Name of simulation
      !
      real(dblprec), dimension(3) :: srvec, m_j
      integer :: lhit, ia, k, iq
      real(dblprec) :: pi, qr
      character(len=30) :: filn
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      !
      !nplot=12
      !q=10.0_dblprec*q
      !
      write(filn,'(''qm_restart.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn)
      !write(ofileno,*) 0
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a,1x,a)') "# File type:", 'R'
      write(ofileno,'(a,1x,a)') "# Simulation type:", 'Q'
      write(ofileno,'(a,1x,i8)')"# Number of atoms: ", Natom
      write(ofileno,'(a,1x,i8)')"# Number of ensembles: ", Mensemble
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a8,a,a8,a16,a16,a16,a16)') "#Timestep","ens","iatom","|Mom|","M_x","M_y","M_z"
      do k=1,Mensemble
         do ia=1,Natom
            lhit=lhit+1
            srvec=coord(:,ia)
            !call wrap_coord_diff(Natom,coord,ia,1,srvec)
            !
            m_j=0.0_dblprec
            do iq=1,3
               qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
               m_j=m_j+n_vec*cos(2*pi*qr)+s(:,iq)*sin(2*pi*qr)
               !m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
            end do
            call normalize(m_j)
            emom(1:3,ia,k)=m_j
            emomM(1:3,ia,k)=m_j*mmom(ia,k)
            !write(ofileno,'(2i8,4f14.6)') 1,lhit,mmom(ia,k),m_j
            !write(ofileno,'(2i8,4f14.6)') 1,ia,mmom(ia,k),m_j
            write(ofileno,10003) 0,1,ia,mmom(ia,k),m_j
         end do
      end do
      close(ofileno)
      !
      !
      10003 format(i8,i8,i8,2x,es16.8,es16.8,es16.8,es16.8)
      !
   end subroutine plot_q3

   !> Plot final configuration
   subroutine plot_cube(Natom, Mensemble, coord, emom, emomM, mmom,simid)
      !
      implicit none
      !
      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emom  !< Current magnetic moment vector
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      character(len=8), intent(in) :: simid  !< Name of simulation
      !
      real(dblprec), dimension(3) :: srvec, m_j
      integer :: lhit, ia, k, iq
      real(dblprec) :: pi, qr
      character(len=30) :: filn
      !
      !
      pi=4._dblprec*ATAN(1._dblprec)
      !
      !nplot=12
      !q=10.0_dblprec*q
      !
      write(filn,'(''qm_restart.'',a,''.out'')') trim(simid)
      open(ofileno,file=filn)
      !write(ofileno,*) 0
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a,1x,a)') "# File type:", 'R'
      write(ofileno,'(a,1x,a)') "# Simulation type:", 'Q'
      write(ofileno,'(a,1x,i8)')"# Number of atoms: ", Natom
      write(ofileno,'(a,1x,i8)')"# Number of ensembles: ", Mensemble
      write(ofileno,'(a)') repeat("#",80)
      write(ofileno,'(a8,a,a8,a16,a16,a16,a16)') "#Timestep","ens","iatom","|Mom|","M_x","M_y","M_z"
      do k=1,Mensemble
         do ia=1,Natom
            lhit=lhit+1
            srvec=coord(:,ia)
            !
            m_j=0.0_dblprec
            do iq=1,3
               qr=q(1,iq)*srvec(1)+q(2,iq)*srvec(2)+q(3,iq)*srvec(3)
               m_j=m_j+n_vec*cos(2*pi*qr)+s(:,iq)*sin(2*pi*qr)
               !m_j=m_j+n_vec*cos(2*pi*qr+phi(iq))+s(:,iq)*sin(2*pi*qr+phi(iq))
            end do
            call normalize(m_j)
            emom(1:3,ia,k)=m_j
            emomM(1:3,ia,k)=m_j*mmom(ia,k)
            !write(ofileno,'(2i8,4f14.6)') 1,lhit,mmom(ia,k),m_j
            !write(ofileno,'(2i8,4f14.6)') 1,ia,mmom(ia,k),m_j
            write(ofileno,10003) 0,1,ia,mmom(ia,k),m_j
         end do
      end do
      close(ofileno)
      !
      10003 format(es16.8,i8,i8,2x,es16.8,es16.8,es16.8,es16.8)
      !
      !
   end subroutine plot_cube

!!!    !> Anisotropy
!!!    subroutine spinspiral_ani_field(Natom,Mensemble,NA,mmom,taniso,sb,hfield,energy)
!!!       !
!!!       implicit none
!!!       !
!!!       integer, intent(in) :: Natom !< Number of atoms in system
!!!       integer, intent(in) :: Mensemble !< Number of ensembles
!!!       integer, intent(in) :: NA  !< Number of atoms in one cell
!!!       real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
!!!       integer, dimension(Natom),intent(in) :: taniso !< Type of anisotropy (0-2)
!!!       real(dblprec), dimension(Natom),intent(in) :: sb !< Ratio between the anisotropies
!!!       real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
!!!       real(dblprec), intent(inout), optional :: energy !< Total energy
!!!       !
!!!       !
!!!       integer :: iq,i
!!!       real(dblprec) :: tt1, tt2, tt3, totmom, qfac
!!!       real(dblprec), dimension(3) :: field
!!!       !
!!!       totmom=0.0_dblprec
!!!       do i=1,NA
!!!          do iq=1,nq
!!!             field=0.0_dblprec
!!!             if (taniso(i)==1.or.taniso(i)==7) then
!!!                ! Uniaxial anisotropy
!!!                tt1=s(1,iq)*ham%eaniso(1,i)+s(2,iq)*ham%eaniso(2,i)+s(3,iq)*ham%eaniso(3,i)
!!!                tt1=tt1*mmom(i,1)*theta(iq)
!!! 
!!!                tt2=ham%kaniso(1,i)+2.0_dblprec*ham%kaniso(2,i)*(1-tt1*tt1)
!!!                !
!!!                tt3= 2.0_dblprec*tt1*tt2
!!! 
!!!                field(1)  = field(1) - tt3*ham%eaniso(1,i)
!!!                field(2)  = field(2) - tt3*ham%eaniso(2,i)
!!!                field(3)  = field(3) - tt3*ham%eaniso(3,i)
!!! 
!!!             end if
!!!             if (ham%taniso(i)==2.or.ham%taniso(i)==7) then
!!!                qfac=1.00
!!!                if(ham%taniso(i)==7) qfac=sb(i)
!!!                ! Cubic anisotropy
!!!                field(1) = field(1)  &
!!!                   + qfac*2.0_dblprec*ham%kaniso(1,i)*mmom(i,1)*s(1,iq)*(mmom(i,1)*s(2,iq)**2+mmom(i,1)*s(3,iq)**2)*theta(iq)**3 &
!!!                   + qfac*2.0_dblprec*ham%kaniso(2,i)*mmom(i,1)*s(1,iq)*mmom(i,1)*s(2,iq)**2*mmom(i,1)*s(3,iq)**2*theta(iq)**5
!!!                field(2) = field(2)  &
!!!                   + qfac*2.0_dblprec*ham%kaniso(1,i)*mmom(i,1)*s(2,iq)*(mmom(i,1)*s(3,iq)**2+mmom(i,1)*s(1,iq)**2) *theta(iq)**3&
!!!                   + qfac*2.0_dblprec*ham%kaniso(2,i)*mmom(i,1)*s(2,iq)*mmom(i,1)*s(3,iq)**2*mmom(i,1)*s(1,iq)**2*theta(iq)**5
!!!                field(3) = field(3)  &
!!!                   + qfac*2.0_dblprec*ham%kaniso(1,i)*mmom(i,1)*s(3,iq)*(mmom(i,1)*s(1,iq)**2+mmom(i,1)*s(2,iq)**2) *theta(iq)**3&
!!!                   + qfac*2.0_dblprec*ham%kaniso(2,i)*mmom(i,1)*s(3,iq)*mmom(i,1)*s(1,iq)**2*mmom(i,1)*s(2,iq)**2*theta(iq)**5
!!!                !
!!!             end if
!!!             energy=energy-(2.0_dblprec*field(1)*mmom(i,1)*theta(iq)*s(1,iq)+2.0_dblprec*field(1)*mmom(2,1)*theta(iq)*s(2,iq)+2.0_dblprec*field(3)*mmom(i,1)*theta(iq)*s(3,iq))
!!!             energy=energy+(hfield(1)*mmom(i,1)*theta(iq)*s(1,iq)+hfield(2)*mmom(i,1)*theta(iq)*s(2,iq)+hfield(3)*mmom(i,1)*theta(iq)*s(3,iq))/nq*0.5_dblprec
!!! 
!!!          end do
!!!       end do
!!!       return
!!!       !
!!!    end subroutine spinspiral_ani_field

   !> Rotation of vectors
   subroutine rotvec(s,m)
      !
      implicit none
      !
      real(dblprec), dimension(3), intent(in) :: s
      real(dblprec), dimension(3), intent(out) :: m
      !
      real(dblprec) :: theta, dot, qnorm
      real(dblprec), dimension(3) :: u,q_new, q
      real(dblprec), dimension(3,3) :: I,ux,uplus, R
      !
      I=0.0_dblprec;I(1,1)=1.0_dblprec;I(2,2)=1.0_dblprec;I(3,3)=1.0_dblprec
      q=(/0.0_dblprec,0.0_dblprec,1.0_dblprec/)
      qnorm=1.0_dblprec
      !
      ! Perpendicular vector
      u(1)=q(2)*s(3)-q(3)*s(2)
      u(2)=q(3)*s(1)-q(1)*s(3)
      u(3)=q(1)*s(2)-q(2)*s(1)
      !
      uplus(1,1)=u(1)*u(1)
      uplus(2,1)=u(1)*u(2)
      uplus(3,1)=u(1)*u(3)
      uplus(1,2)=u(2)*u(1)
      uplus(2,2)=u(2)*u(2)
      uplus(3,2)=u(2)*u(3)
      uplus(1,3)=u(3)*u(1)
      uplus(2,3)=u(3)*u(2)
      uplus(3,3)=u(3)*u(3)
      !
      ux=0.0_dblprec
      ux(2,1)=-u(3)
      ux(3,1)= u(2)
      ux(1,2)= u(3)
      ux(3,2)=-u(1)
      ux(1,3)=-u(2)
      ux(2,3)= u(1)
      !
      dot=q(1)*s(1)+q(2)*s(2)+q(3)*s(3)
      dot=dot/qnorm
      theta=acos(dot)
      !
      R=cos(theta)*I+sin(theta)*ux+(1.0_dblprec-cos(theta))*uplus
      !
      q_new(1)=R(1,1)*m(1)+R(2,1)*m(2)+R(3,1)*m(3)
      q_new(2)=R(1,2)*m(1)+R(2,2)*m(2)+R(3,2)*m(3)
      q_new(3)=R(1,3)*m(1)+R(2,3)*m(2)+R(3,3)*m(3)
      !
      m=q_new
      !
      return
      !
   end subroutine rotvec

   !> Normalization
   subroutine normalize(v)
      !
      implicit none
      !
      real(dblprec),dimension(3), intent(inout) :: v
      !
      real(dblprec) :: vnorm
      !
      vnorm=sqrt(sum(v**2))
      if(vnorm>0.0_dblprec)  v=v/vnorm
      !
      return
   end subroutine normalize

!!!    !> Update moment
!!!    subroutine updatrotmom_single(m_in,s_vec)
!!!       !
!!!       !
!!!       !.. Implicit Declarations ..
!!!       implicit none
!!!       !
!!!       !
!!!       !.. Formal Arguments ..
!!!       real(dblprec), dimension(3), intent(inout) :: m_in
!!!       real(dblprec), dimension(3), intent(in) :: s_vec
!!!       !
!!!       !
!!!       !.. Local Scalars ..
!!!       integer :: j
!!!       real(dblprec) :: alfa, beta
!!!       !
!!!       !.. Local Arrays ..
!!!       real(dblprec), dimension(3) :: v,vout, sv, mz
!!!       real(dblprec), dimension(3,3) :: Rx, Ry, Rz
!!!       !
!!!       !
!!!       ! ... Executable Statements ...
!!!       !
!!!       !
!!!       mz=(/0.0_dblprec,0.0_dblprec,1.0_dblprec/)
!!!       do j=1,3
!!!          v(j)=s_vec(j)
!!!       end do
!!!       !
!!!       ! Plan B) User Euler rotation
!!!       !
!!!       call car2sph(v,sv)
!!!       alfa=0.0_dblprec*atan(1.0_dblprec)+sv(2)
!!!       beta=-0.0_dblprec*atan(1.0_dblprec)+sv(1)
!!!       ! Rx
!!!       Rx(1,1)=1.0_dblprec
!!!       Rx(2,1)=0.0_dblprec
!!!       Rx(3,1)=0.0_dblprec
!!!       Rx(1,2)=0.0_dblprec
!!!       Rx(2,2)=cos(alfa)
!!!       Rx(3,2)=sin(alfa)
!!!       Rx(1,3)=0.0_dblprec
!!!       Rx(2,3)=-sin(alfa)
!!!       Rx(3,3)=cos(alfa)
!!!       ! Ry
!!!       Ry(1,1)=cos(alfa)
!!!       Ry(2,1)=0.0_dblprec
!!!       Ry(3,1)=-sin(alfa)
!!!       Ry(1,2)=0.0_dblprec
!!!       Ry(2,2)=1.0_dblprec
!!!       Ry(3,2)=0.0_dblprec
!!!       Ry(1,3)=sin(alfa)
!!!       Ry(2,3)=0.0_dblprec
!!!       Ry(3,3)=cos(alfa)
!!!       !! Rz
!!!       Rz(1,1)=cos(beta)
!!!       Rz(2,1)=sin(beta)
!!!       Rz(3,1)=0.0_dblprec
!!!       Rz(1,2)=-sin(beta)
!!!       Rz(2,2)=cos(beta)
!!!       Rz(3,2)=0.0_dblprec
!!!       Rz(1,3)=0.0_dblprec
!!!       Rz(2,3)=0.0_dblprec
!!!       Rz(3,3)=1.0_dblprec
!!!       ! Rotate!
!!!       v=m_in
!!!       vout=matmul(Rz,matmul(Ry,v))
!!!       do j=1,3
!!!          m_in(j)=vout(j)
!!!       end do
!!!       return
!!!       !
!!!       ! ... Format Declarations ...
!!!       !
!!!    end subroutine updatrotmom_single

!!!    !> transforms cartesian (x,y,z) to spherical (Theta,Phi,R) coordinates
!!!    subroutine car2sph(C,S)
!!!       ! transforms cartesian (x,y,z) to spherical (Theta,Phi,R) coordinates
!!!       !
!!!       !
!!!       !.. Implicit Declarations ..
!!!       implicit none
!!!       !
!!!       !
!!!       !.. Formal Arguments ..
!!!       real(dblprec) :: X,Y,Z, THETA, PHI, D2, R2
!!!       real(dblprec), dimension(3), intent(in) :: C
!!!       real(dblprec), dimension(3), intent(out) :: S
!!!       !
!!!       !
!!!       ! ... Executable Statements ...
!!!       !
!!!       !
!!!       X = C(1)
!!!       Y = C(2)
!!!       Z = C(3)
!!!       D2 = X*X + Y*Y
!!!       R2 = X*X + Y*Y + Z*Z
!!! 
!!!       IF ( D2 .EQ. 0_dblprec ) THEN
!!!          THETA = 0_dblprec
!!!       ELSE
!!!          THETA = ATAN2(Y,X)
!!!       END IF
!!!       PHI = ACOS(Z/R2)
!!! 
!!!       S(1)=THETA
!!!       S(2)=PHI
!!!       S(3)=R2
!!!       return
!!!       !
!!!    end subroutine car2sph

   !-----------------------------------------------------------------------------
   ! SUBROUTINE: qmc
   !> @ brief Energy minimization
   !> @author Anders Bergman
   !-----------------------------------------------------------------------------
   subroutine qmc(Natom,Mensemble,NA,N1,N2,N3,coord,     &
      emomM,mmom,hfield,OPT_flag,     &
      max_no_constellations,maxNoConstl,unitCellType,constlNCoup,constellations,    &
      constellationsNeighType,Num_macro,cell_index,emomM_macro,           &
      macro_nlistsize)
      !
      use Constants, only: k_bolt, mub
      use InputData, only: Temp
      use RandomNumbers, only : rng_uniform
      !.. Implicit declarations
      implicit none

      integer, intent(in) :: Natom !< Number of atoms in system
      integer, intent(in) :: Mensemble !< Number of ensembles
      integer, intent(in) :: NA  !< Number of atoms in one cell
      integer, intent(in) :: N1
      integer, intent(in) :: N2
      integer, intent(in) :: N3
      real(dblprec), dimension(3,Natom), intent(in) :: coord !< Coordinates of atoms
      real(dblprec), dimension(3,Natom,Mensemble), intent(inout) :: emomM  !< Current magnetic moment vector
      real(dblprec), dimension(Natom,Mensemble), intent(in) :: mmom !< Magnitude of magnetic moments
      real(dblprec), dimension(3), intent(in) :: hfield !< Constant effective field
      !! +++ New variables due to optimization routines +++ !!
      integer, intent(in) :: max_no_constellations ! The maximum (global) length of the constellation matrix
      ! Number of entries (number of unit cells*number of atoms per unit cell) in the constellation matrix per ensemble
      integer, dimension(Mensemble), intent(in) :: maxNoConstl
      ! See OptimizationRoutines.f90 for details on classification
      integer, dimension(Natom, Mensemble), intent(in) :: unitCellType ! Array of constellation id and classification (core, boundary, or noise) per atom
      ! Matrix relating the interatomic exchanges for each atom in the constellation matrix
      real(dblprec), dimension(ham%max_no_neigh, max_no_constellations,Mensemble), intent(in) :: constlNCoup
      ! Matrix storing all unit cells belonging to any constellation
      real(dblprec), dimension(3,max_no_constellations, Mensemble), intent(in) :: constellations
      ! Optimization flag (1 = optimization on; 0 = optimization off)
      logical, intent(in) :: OPT_flag
      ! Matrix storing the type of the neighbours within a given neighbourhood of a constellation; default is 1 outside the neighbourhood region
      ! The default is to achieve correct indexing. Note here also that constlNCoup will result in a net zero contribution to the Heissenberg exchange term
      integer, dimension(ham%max_no_neigh,max_no_constellations,Mensemble), intent(in) :: constellationsNeighType
      ! Internal effective field arising from the optimization of the Heissenberg exchange term
      integer, intent(in) :: Num_macro !< Number of macrocells in the system
      integer, dimension(Natom), intent(in) :: cell_index !< Macrocell index for each atom
      real(dblprec), dimension(3,Num_macro,Mensemble), intent(in) :: emomM_macro !< The full vector of the macrocell magnetic moment
      integer, dimension(Num_macro), intent(in) :: macro_nlistsize

      ! .. Local variables
      integer :: iq
      !
      real(dblprec), dimension(3) :: m_i, m_j
      real(dblprec) :: pi, qr, rn(3)
      integer :: i,j, k, ia, ja, lhit, nhits
      real(dblprec) :: energy, old_energy, flipprob(1), de, beta
      real(dblprec), dimension(3) :: avgmom
      real(dblprec) :: avgM
      !
      real(dblprec), dimension(3,3) :: q_trial, s_trial
      !real(dblprec), dimension(3,3) :: s_save, q_save
      real(dblprec), dimension(3) :: theta_trial, phi_trial
      !real(dblprec), dimension(3) :: phi_save, phi_diff, phi_best
      real(dblprec), dimension(3,Natom,Mensemble) :: emomM_tmp
      !
      integer :: niter, iter, iscale

      !
      pi=4._dblprec*ATAN(1._dblprec)
      !
      niter=15000000
      do iq=1,nq
         s(1,iq)=0.0_dblprec;s(2,iq)=0.0_dblprec;s(3,iq)=1.0_dblprec
         theta(iq)=90
         theta(iq)=theta(iq)*pi/180.0_dblprec
         phi(iq)=0.0_dblprec
         !
         q(1,iq)=0.0_dblprec;q(2,iq)=0.0_dblprec;q(3,iq)=1.0_dblprec
      end do

      lhit=0
      nhits=0
      iscale=1

      fac_2d=1.0_dblprec
      if(sum(coord(3,:)**2)==0) fac_2d=0.0_dblprec

      ! Calculate total external field
      do k=1,Mensemble
         do i=1,Natom
            external_field(1:3,i,k)=hfield
            beff(1:3,i,k)=0.0_dblprec
            beff1(1:3,i,k)=0.0_dblprec
            beff2(1:3,i,k)=0.0_dblprec
         end do
      end do

      energy=0.0_dblprec
      call effective_field(Natom,Mensemble,1,na, &
         emomM,mmom,external_field,       &
         time_external_field,beff,beff1,beff2,OPT_flag,max_no_constellations,       &
         maxNoConstl,unitCellType,constlNCoup,constellations,                       &
         constellationsNeighType,energy,Num_macro,cell_index,emomM_macro, &
         macro_nlistsize,NA,N1,N2,N3)
      old_energy=energy
      print *, 'Starting energy:',energy
      do iter=1,niter
         !
         !
         !
         do iq=1,nq
            ! delta q-vector
            call rng_uniform(rn,3)
            q_trial(1,iq)=2.0_dblprec*rn(1)-1.0_dblprec
            q_trial(2,iq)=2.0_dblprec*rn(2)-1.0_dblprec
            q_trial(3,iq)=2.0_dblprec*rn(3)-1.0_dblprec
            !
            ! delta s-vector
            call rng_uniform(rn,3)
            s_trial(1,iq)=2.0_dblprec*rn(1)-1.0_dblprec
            s_trial(2,iq)=2.0_dblprec*rn(2)-1.0_dblprec
            s_trial(3,iq)=2.0_dblprec*rn(3)-1.0_dblprec
            !
            ! theta angle
            call rng_uniform(rn,3)
            theta_trial(iq)=(rn(1)-0.5_dblprec)*pi
            ! phi angle
            phi_trial(iq)=(rn(2)-0.5_dblprec)*pi
            !
         end do
         ! Set up trial vectors
         do iq=1,nq
            call normalize(s_trial(1:3,iq))
         end do
         !
         avgmom=0.0_dblprec
         do k=1,Mensemble
            do ia=1,NA
               avgmom=avgmom+emomM(1:3,ia,k)/ham%nlistsize(ia)/NA
               do j=1,ham%nlistsize(ia)
                  ja=ham%nlist(j,ia)
                  avgmom=avgmom+emomM(1:3,ja,k)/ham%nlistsize(ia)/NA
               end do
            end do
         end do
         avgm=(sum(avgmom)**2)**0.5_dblprec
         ! Set up spin-spiral magnetization (only first cell+ neighbours)
         do k=1,Mensemble
            energy=0.0_dblprec
            do ia=1,NA
               m_i=emomM(1:3,ia,k)
               do iq=1,nq
                  qr=q_trial(1,iq)*coord(1,ia)+q_trial(2,iq)*coord(2,ia)+q_trial(3,iq)*coord(3,ia)
                  call normalize(m_i)
                  m_i=m_i*mmom(ia,k)/nq
                  m_i(1)=m_i(1)+cos(2*pi*qr+phi_trial(iq))*sin(theta_trial(iq))*mmom(ia,k)/nq
                  m_i(2)=m_i(2)+sin(2*pi*qr+phi_trial(iq))*sin(theta_trial(iq))*mmom(ia,k)/nq
                  m_i(3)=m_i(3)+cos(theta_trial(iq))*mmom(ia,k)/nq
                  call rotvec(s_trial(1:3,iq),m_i)
                  call normalize(m_i)
                  m_i=m_i*mmom(ia,k)/nq
               end do
               !energy=energy+kani_cell(ia)*(1-(eani_cell(1,ia)*m_i(1)+eani_cell(2,ia)*m_i(2)+eani_cell(3,ia)*m_i(3))**2)
               emomM_tmp(1:3,ia,k)=emomM(1:3,ia,k)
               emomM(1:3,ia,k)=m_i
               do j=1,ham%nlistsize(ia)
                  ja=ham%nlist(j,ia)
                  m_j=emomM(1:3,ja,k)
                  do iq=1,nq
                     call normalize(m_j)
                     m_j=m_j*mmom(ja,k)/nq
                     qr=q_trial(1,nq)*coord(1,ja)+q_trial(2,nq)*coord(2,ja)+q_trial(3,nq)*coord(3,ja)
                     m_j(1)=m_j(1)+cos(2*pi*qr+phi_trial(iq))*sin(theta_trial(iq))*mmom(ja,k)/nq
                     m_j(2)=m_j(2)+sin(2*pi*qr+phi_trial(iq))*sin(theta_trial(iq))*mmom(ja,k)/nq
                     m_j(3)=m_j(3)+cos(theta_trial(iq))*mmom(ja,k)/nq
                     call rotvec(s_trial(1:3,iq),m_j)
                     call normalize(m_j)
                     m_j=m_j*mmom(ja,k)/nq
                  end do
                  emomM_tmp(1:3,ja,k)=emomM(1:3,ja,k)
                  emomM(1:3,ja,k)=m_j
               end do
               ! Calculate energy for given q,s,theta combination
               call effective_field(Natom,Mensemble,ia,ia,emomM,mmom,   &
                  external_field,time_external_field,beff,beff1,beff2,OPT_flag,     &
                  max_no_constellations,maxNoConstl,unitCellType,constlNCoup,       &
                  constellations,constellationsNeighType,energy,Num_macro,&
                  cell_index,emomM_macro,macro_nlistsize,NA,N1,N2,N3)
            end do
         end do
         ! Store best energy configuration
         call rng_uniform(flipprob,1)
         beta=1_dblprec/k_bolt/Temp
         de=(energy-old_energy)*mub
         if(de<=0.0_dblprec .or. flipprob(1)<=exp(-beta*de)) then
            nhits=nhits+1
            old_energy=energy
            print '(1x,a,i8,4f24.6)', 'QMC: ',nhits,avgm, energy, old_energy, de
            print '(1x,a,3f12.6)', '     ',emomM(1:3,1,1)-emomM(1:3,2,1)
         else
            avgmom=0.0_dblprec
            do k=1,Mensemble
               do ia=1,NA
                  emomM(1:3,ia,k)=emomM_tmp(1:3,ia,k)
                  avgmom=avgmom+emomM(1:3,ia,k)/ham%nlistsize(ia)/NA
                  do j=1,ham%nlistsize(ia)
                     ja=ham%nlist(j,ia)
                     emomM(1:3,ja,k)=emomM_tmp(1:3,ja,k)
                     avgmom=avgmom+emomM(1:3,ja,k)/ham%nlistsize(ia)/NA
                  end do
               end do
            end do
            avgm=(sum(avgmom)**2)**0.5_dblprec
         end if

      end do
      !
      return
      !
   end subroutine qmc

   !---------------------------------------------------------------------------
   !> @brief
   !> Read input parameters.
   !
   !> @author
   !> Anders Bergman
   !---------------------------------------------------------------------------
   subroutine read_parameters_qminimizer(ifile)

      use FileParser

      implicit none

      ! ... Formal Arguments ...
      integer, intent(in) :: ifile   !< File to read from
      !
      ! ... Local Variables ...
      character(len=50) :: keyword
      integer :: rd_len, i_err, i_errb
      logical :: comment



      do
         10     continue
         ! Read file character for character until first whitespace
         keyword=""
         call bytereader(keyword,rd_len,ifile,i_errb)

         ! converting Capital letters
         call caps2small(keyword)

         ! check for comment markers (currently % and #)
         comment=(scan(trim(keyword),'%')==1).or.(scan(trim(keyword),'#')==1).or.&
            (scan(trim(keyword),'*')==1).or.(scan(trim(keyword),'=')==1.or.&
            (scan(trim(keyword),'!')==1))

         if (comment) then
            read(ifile,*)
         else
            ! Parse keyword
            keyword=trim(keyword)
            select case(keyword)
         case('qm_min')
            read(ifile,*,iostat=i_err) q_min
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_max')
            read(ifile,*,iostat=i_err) q_max
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_type')
            read(ifile,*,iostat=i_err) qm_type
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_rot')
            read(ifile,*,iostat=i_err) qm_rot
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_oaxis')
            read(ifile,*,iostat=i_err) qm_oaxis
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_qvec')
            read(ifile,*,iostat=i_err) q(:,1:nq)
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_svec')
            read(ifile,*,iostat=i_err) s(:,1:nq)
            s(:,1)=s(:,1)/norm2(s(:,1)+dbl_tolerance)
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_nvec')
            read(ifile,*,iostat=i_err) n_vec
            n_vec=n_vec/norm2(n_vec+dbl_tolerance)
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         case('qm_nstep')
            read(ifile,*,iostat=i_err) nstep
            if(i_err/=0) write(*,*) 'ERROR: Reading ',trim(keyword),' data',i_err
         end select
      end if

      ! End of file
      if (i_errb==20) goto 20
      ! End of row
      if (i_errb==10) goto 10
   end do

   20  continue

   rewind(ifile)
   return
end subroutine read_parameters_qminimizer

subroutine qminimizer_init()
   !
   implicit none
   !
   q_min=-1.0_dblprec
   q_max=1.0_dblprec
   q=0.0_dblprec
   q(3,1)=1.0_dblprec
   n_vec=0.0_dblprec
   n_vec(3)=1.0_dblprec
   s=0.0_dblprec
   nstep=1000
   qm_rot='N'
   qm_oaxis='N'

end subroutine qminimizer_init

subroutine set_nsvec(qm_type,q_vec,s_vec,n_vec)
   use RandomNumbers, only : rng_uniform
   use math_functions, only : f_cross_product

   !
   implicit none
   !
   character*1, intent(in) :: qm_type
   real(dblprec), dimension(3), intent(in) :: q_vec
   real(dblprec), dimension(3), intent(inout) :: s_vec
   real(dblprec), dimension(3), intent(inout) :: n_vec
   !
   real(dblprec), dimension(3) :: r_vec
   real(dblprec), dimension(3) :: c_vec
   real(dblprec) :: v_norm, r_norm
   !
   if(qm_type=='C') then
      n_vec = q_vec
      v_norm=norm2(n_vec)
      if(v_norm==0.0d0) then
         n_vec(1)=0.0_dblprec;n_vec(2)=0.0_dblprec;n_vec(3)=1.0_dblprec
      else
         n_vec = n_vec/v_norm
      end if

      v_norm = 0.0_dblprec
      do while (v_norm<1e-6) 
         call rng_uniform(r_vec,3)
         r_vec = 2.0_dblprec*r_vec - 1.0_dblprec
         r_norm = norm2(r_vec)
         r_vec = r_vec/r_norm

         c_vec =  f_cross_product(n_vec,r_vec)
         v_norm = norm2(c_vec)
      end do
      s_vec = c_vec/v_norm

   else if(qm_type=='H') then
      v_norm = 0.0_dblprec
      do while (v_norm<1e-6) 
         call rng_uniform(r_vec,3)
         r_vec = 2.0_dblprec*r_vec - 1.0_dblprec
         r_norm = norm2(r_vec)
         r_vec = r_vec/r_norm

         c_vec =  f_cross_product(q_vec,r_vec)
         v_norm = norm2(c_vec)
      end do
      s_vec = c_vec/v_norm
      n_vec = f_cross_product(q_vec,s_vec)
      v_norm = norm2(n_vec)
      n_vec = n_vec/v_norm
   end if

end subroutine set_nsvec
end module qminimizer
