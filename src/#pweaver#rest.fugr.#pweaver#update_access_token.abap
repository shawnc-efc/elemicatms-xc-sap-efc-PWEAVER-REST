FUNCTION /pweaver/update_access_token.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(ACCESS_TOKEN) TYPE  /PWEAVER/ACCESS_TOKEN OPTIONAL
*"     VALUE(REFRESH_TOKEN) TYPE  /PWEAVER/REFRESH_TOKEN OPTIONAL
*"     VALUE(SHIPURL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"----------------------------------------------------------------------



  CONSTANTS: lc_fedex    TYPE char10 VALUE 'FEDEX',
             lc_pod      TYPE char5  VALUE 'POD',
             lc_podimage TYPE char15 VALUE 'PODIMAGE',
             lc_fedexett TYPE char10 VALUE 'FEDEXETT',
             lc_ett_rtg  TYPE char10 VALUE 'ETTRTG',
             lc_ltl      TYPE char10 VALUE 'LTL'.

  IF access_token IS NOT INITIAL OR refresh_token IS NOT INITIAL.
    DATA: ls_token TYPE /pweaver/tokens.

    CALL FUNCTION '/PWEAVER/GET_ACCESS_TOKEN'
      EXPORTING
        carrierconfig   = carrierconfig
        shipurl         = shipurl
      IMPORTING
        tokens          = ls_token
      EXCEPTIONS
        no_tokens_found = 1
        OTHERS          = 2.

    IF sy-subrc <> 0.
      ls_token-carriertype = carrierconfig-carriertype.
      ls_token-accountnumber = carrierconfig-accountnumber.
      ls_token-refresh_token = refresh_token.
      ls_token-access_token = access_token.
    ELSE.
      IF access_token <> ls_token-access_token OR
      refresh_token <> ls_token-refresh_token.
        ls_token-refresh_token = refresh_token.
        ls_token-access_token = access_token.
      ENDIF.
    ENDIF.
    IF ls_token IS NOT INITIAL.
      IF ( shipurl-carriertype = lc_fedex OR shipurl-carrieridf = lc_fedex ) AND
      ( shipurl-pwmodule = lc_pod OR shipurl-pwmodule = lc_podimage OR shipurl-pwmodule = lc_ett_rtg ).
        ls_token-carriertype = lc_fedexett.
      ENDIF.
      IF carrierconfig-carriertype = lc_ltl AND carrierconfig-carrieridf IS NOT INITIAL.
        ls_token-carriertype = carrierconfig-carrieridf.
      ENDIF.
      MODIFY /pweaver/tokens FROM ls_token.
      COMMIT WORK.
    ENDIF.
  ENDIF.

ENDFUNCTION.
