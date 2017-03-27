MODULE out_cif
!
!
!**********************************************************************************
!*  OUT_CIF                                                                       *
!**********************************************************************************
!* This module writes a Crystallographic Information Files (CIF).                 *
!* The CIF format is officially described in the following articles:              *
!*     S.R.Hall, F.H. Allen, I.D. Brown, Acta Cryst. A 47 (1991) 655–685          *
!*     I.D. Brown, B. McMahon, Acta Cryst. B 58 (2002) 317–24                     *
!* and also on the Web site of the International Union of Crystallography:        *
!*     http://www.iucr.org/resources/cif/                                         *
!**********************************************************************************
!* (C) Oct. 2012 - Pierre Hirel                                                   *
!*     Université de Lille, Sciences et Technologies                              *
!*     UMR CNRS 8207, UMET - C6, F-59655 Villeneuve D'Ascq, France                *
!*     pierre.hirel@univ-lille1.fr                                                *
!* Last modification: P. Hirel - 27 March 2017                                    *
!**********************************************************************************
!* This program is free software: you can redistribute it and/or modify           *
!* it under the terms of the GNU General Public License as published by           *
!* the Free Software Foundation, either version 3 of the License, or              *
!* (at your option) any later version.                                            *
!*                                                                                *
!* This program is distributed in the hope that it will be useful,                *
!* but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
!* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                  *
!* GNU General Public License for more details.                                   *
!*                                                                                *
!* You should have received a copy of the GNU General Public License              *
!* along with this program.  If not, see <http://www.gnu.org/licenses/>.          *
!**********************************************************************************
!
USE atoms
USE comv
USE constants
USE functions
USE messages
USE files
USE subroutines
!
IMPLICIT NONE
!
!
CONTAINS
!
SUBROUTINE WRITE_CIF(H,P,comment,AUXNAMES,AUX,outputfile)
!
CHARACTER(LEN=*),INTENT(IN):: outputfile
CHARACTER(LEN=2):: species
CHARACTER(LEN=5):: zone
CHARACTER(LEN=8):: date
CHARACTER(LEN=10):: time
CHARACTER(LEN=16):: month, smonth
CHARACTER(LEN=4096):: msg, temp, tempaux
CHARACTER(LEN=128),DIMENSION(:),ALLOCATABLE,INTENT(IN):: AUXNAMES !names of auxiliary properties
CHARACTER(LEN=128),DIMENSION(:),ALLOCATABLE,INTENT(IN):: comment
INTEGER:: i, iaux
INTEGER:: Naux
INTEGER:: occ, q, qs, biso, uiso !index of occupancies, electric charge, Biso, in AUX
INTEGER,DIMENSION(8):: values
REAL(dp):: a, b, c, alpha, beta, gamma !supercell (conventional notation)
REAL(dp):: charge   !electric charge of an ion
REAL(dp):: P1, P2, P3
REAL(dp):: smass, smass_tot !mass of one element, of the compound
REAL(dp):: Vcell  !supercell volume
REAL(dp),DIMENSION(3,3),INTENT(IN):: H   !Base vectors of the supercell
REAL(dp),DIMENSION(3,3):: G   !Invert of H
REAL(dp),DIMENSION(:,:),ALLOCATABLE:: aentries
REAL(dp),DIMENSION(:,:),ALLOCATABLE,INTENT(IN):: P
REAL(dp),DIMENSION(:,:),ALLOCATABLE,INTENT(IN):: AUX !auxiliary properties
!
!
!Initialize variables
q = 0
qs = 0
occ = 0
biso = 0
uiso = 0
Naux = 0
!
CALL INVMAT(H,G)
IF (ALLOCATED(AUX) .AND. SIZE(AUX,2)==SIZE(AUXNAMES) ) THEN ! Get number of auxiliary properties
  Naux = SIZE(AUX,2) ! ? Redundant but maybe better MIN(SIZE(AUX,2),SIZE(AUXNAMES))
ENDIF
!
msg = 'entering WRITE_CIF'
CALL ATOMSK_MSG(999,(/msg/),(/0.d0/))
!
!
!
100 CONTINUE
OPEN(UNIT=40,FILE=outputfile,STATUS='UNKNOWN',ERR=800)
!
!
CALL DATE_AND_TIME(DATE, TIME, ZONE, VALUES)
CALL INT2MONTH(VALUES(2),month,smonth)
WRITE(msg,'(i2,a2,i4)') VALUES(3), ", ", VALUES(1)
WRITE(temp,*) "_audit_creation_date      '"//TRIM(smonth)//" "//TRIM(ADJUSTL(msg))//"'"
WRITE(40,'(a)') TRIM(ADJUSTL(temp))
WRITE(40,'(a)') "_audit_creation_method    'Draft CIF file generated with Atomsk'"
!
!
!Find number of atoms for each species
!Determine formula and mass of the compound
!
! Remark by J.B.: The sum formula may be incorrect in case of
!                 partial occupancies.
!
CALL FIND_NSP(P(:,4),aentries)
msg=''
smass_tot=0.d0
DO i=1,SIZE(aentries,1)
  CALL ATOMSPECIES(aentries(i,1),species)
  temp=''
  IF( NINT(aentries(i,2))>1 ) THEN
    WRITE(temp,'(i10)') NINT(aentries(i,2))
    temp = TRIM(species)//TRIM(ADJUSTL(temp))
  ELSE
    temp = TRIM(species)
  ENDIF
  msg = TRIM(ADJUSTL(msg))//" "//TRIM(ADJUSTL(temp))
  CALL ATOMMASS(species,smass)
  smass_tot = smass_tot + smass*aentries(i,2)
ENDDO
WRITE(40,*) ""
WRITE(40,'(a)') "_chemical_name_common             ?"
WRITE(40,'(a)') "_chemical_melting_point           ?"
WRITE(40,'(a)') "_chemical_formula_iupac           '"//TRIM(ADJUSTL(msg))//"'"
WRITE(40,'(a)') "_chemical_formula_moiety          '"//TRIM(ADJUSTL(msg))//"'"
WRITE(40,'(a)') "_chemical_formula_sum             '"//TRIM(ADJUSTL(msg))//"'"
WRITE(msg,'(f16.3)') smass_tot
WRITE(40,'(a)') "_chemical_formula_weight          "//TRIM(ADJUSTL(msg))
WRITE(40,'(a)') "_chemical_compound_source         ?"
WRITE(40,'(a)') "_chemical_absolute_configuration  ?"
!
!
!Write space group information
!NOTE: here space group P1 is always assumed
WRITE(40,*) ""
WRITE(40,'(a)') "_space_group_IT_number            1"
WRITE(40,'(a)') "_symmetry_cell_setting            triclinic"
WRITE(40,'(a)') "_symmetry_space_group_name_Hall   'P 1'"
WRITE(40,'(a)') "_symmetry_space_group_name_H-M    'P 1'"
!
!Write cell vectors (conventional notation, angles in degrees)
WRITE(40,*) ""
CALL MATCONV(H,a,b,c,alpha,beta,gamma)
WRITE(temp,'(f16.4)') a
WRITE(40,'(a)') '_cell_length_a                    '//TRIM(ADJUSTL(temp))
WRITE(temp,'(f16.4)') b
WRITE(40,'(a)') '_cell_length_b                    '//TRIM(ADJUSTL(temp))
WRITE(temp,'(f16.4)') c
WRITE(40,'(a)') '_cell_length_c                    '//TRIM(ADJUSTL(temp))
WRITE(temp,'(f16.4)') alpha*180.d0/pi
WRITE(40,'(a)') '_cell_angle_alpha                 '//TRIM(ADJUSTL(temp))
WRITE(temp,'(f16.4)') beta*180.d0/pi
WRITE(40,'(a)') '_cell_angle_beta                  '//TRIM(ADJUSTL(temp))
WRITE(temp,'(f16.4)') gamma*180.d0/pi
WRITE(40,'(a)') '_cell_angle_gamma                 '//TRIM(ADJUSTL(temp))
CALL VOLUME_PARA(H,Vcell)
WRITE(temp,'(f16.4)') Vcell
WRITE(40,'(a)') '_cell_volume                      '//TRIM(ADJUSTL(temp))
!
!
!Write atom positions
WRITE(40,*) ""
WRITE(40,'(a5)') "loop_"
WRITE(40,'(a23)') " _atom_site_type_symbol"
WRITE(40,'(a19)') " _atom_site_fract_x"
WRITE(40,'(a19)') " _atom_site_fract_y"
WRITE(40,'(a19)') " _atom_site_fract_z"
IF (Naux>0) THEN
  DO iaux=1,SIZE(AUXNAMES)
    ! write supported auxiliary propertie loop items
    IF (TRIM(AUXNAMES(iaux))=="occ") THEN
      WRITE(40,'(a21)') " _atom_site_occupancy"
      occ = iaux
    ELSEIF(TRIM(AUXNAMES(iaux))=="q") THEN
      q = iaux
    ELSEIF(TRIM(AUXNAMES(iaux))=="qs") THEN
      qs = iaux
    ELSEIF(TRIM(AUXNAMES(iaux))=="biso") THEN
      WRITE(40,'(a33)') " _atom_site_thermal_displace_type"
      WRITE(40,'(a26)') " _atom_site_B_iso_or_equiv"
      biso = iaux
    ELSEIF(TRIM(AUXNAMES(iaux))=="uiso" .AND. biso==0 ) THEN
      WRITE(40,'(a33)') " _atom_site_thermal_displace_type"
      WRITE(40,'(a26)') " _atom_site_B_iso_or_equiv"
      uiso = iaux
    ENDIF
  ENDDO
ENDIF
DO i=1,SIZE(P,1)
  ! Get species string
  CALL ATOMSPECIES(P(i,4),species)
  month = species
  IF( q>0 .AND. q<=SIZE(AUX,2) ) THEN
    !Electric charge defined => append it to species name
    charge = AUX(i,q)
    IF( qs>0 ) THEN
      !There was a core-shell model, and AUX contains the charge of the shell
      !Total charge of the ion is charge of core + charge of shell
      charge = charge + AUX(i,qs)
    ENDIF
    temp = ''
    IF( DABS( DBLE(NINT(charge)) - charge ) < 1.d-12 ) THEN
      !Charge is integer
      IF( NINT(DABS(charge))>1 ) THEN
        WRITE(temp,'(i9)') NINT(DABS( charge ))
      ENDIF
    ELSE
      !Charge is a real number
      WRITE(temp,'(f9.3)') DABS( charge )
    ENDIF
    IF( charge<-1.d-12 ) THEN
      month = TRIM(ADJUSTL(month))//TRIM(ADJUSTL(temp))//"-"
    ELSEIF( charge>1.d-12 ) THEN
      month = TRIM(ADJUSTL(month))//TRIM(ADJUSTL(temp))//"+"
    ELSE
      month = TRIM(ADJUSTL(month))
    ENDIF
  ENDIF
  ! Prepare string with fractional x,y,z atom position in the cell
  P1 = P(i,1)
  P2 = P(i,2)
  P3 = P(i,3)
  WRITE(temp,'(3(f9.6,1X))')  P1*G(1,1) + P2*G(2,1) + P3*G(3,1),     &
                           &  P1*G(1,2) + P2*G(2,2) + P3*G(3,2),     &
                           &  P1*G(1,3) + P2*G(2,3) + P3*G(3,3)
  ! add strings of auxiliary properties to temp
  tempaux = ""
  IF (Naux>0) THEN
    DO iaux=1, Naux
      WRITE(tempaux,'(f9.6)') AUX(i,iaux)
      IF (iaux==occ) WRITE(temp,*) TRIM(ADJUSTL(temp))//' '//        &
                                 & TRIM(ADJUSTL(tempaux))
      IF (iaux==biso) WRITE(temp,*) TRIM(ADJUSTL(temp))//' Biso '//  &
                                  & TRIM(ADJUSTL(tempaux))
      IF (iaux==uiso) WRITE(temp,*) TRIM(ADJUSTL(temp))//' Uiso '//  &
                                  & TRIM(ADJUSTL(tempaux))
    ENDDO
  ENDIF
  ! combine the strings
  WRITE(temp,*) TRIM(ADJUSTL(month))//'  '//TRIM(ADJUSTL(temp))
  ! write to file
  WRITE(40,'(a)') TRIM(ADJUSTL(temp(1:80)))
ENDDO
!
!
!
200 CONTINUE
CLOSE(40)
msg = "CIF"
temp = outputfile
CALL ATOMSK_MSG(3002,(/msg,temp/),(/0.d0/))
GOTO 1000
!
!
!
800 CONTINUE
nerr=nerr+1
!
!
!
1000 CONTINUE
!
!
END SUBROUTINE WRITE_CIF
!
END MODULE out_cif
