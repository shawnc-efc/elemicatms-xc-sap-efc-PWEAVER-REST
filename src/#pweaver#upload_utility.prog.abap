*&---------------------------------------------------------------------*
*& Report  /PWEAVER/UPLOAD_UTILITY
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT  /pweaver/upload_utility.

TYPE-POOLS : truxs.

DATA : gr_tab TYPE REF TO data,
       gr_wa  TYPE REF TO data.

DATA : gt_filename TYPE filetable,
       gv_return   TYPE i,
       gt_rawdata TYPE truxs_t_text_data,
       gs_rawdata LIKE LINE OF gt_rawdata,
       gv_strfield TYPE string,
       go_type     TYPE REF TO cl_abap_typedescr.
FIELD-SYMBOLS :
               <gfs_table> TYPE STANDARD TABLE,
               <gfs_wa>    TYPE ANY,
               <gfs_field> TYPE ANY.



PARAMETERS :

             p_tname TYPE string OBLIGATORY,
             p_fname TYPE string,
             p_prvw  TYPE c AS CHECKBOX DEFAULT 'X',
             p_updt  TYPE c AS CHECKBOX,
             p_refr  TYPE c AS CHECKBOX,
             p_dasl  TYPE c DEFAULT '2',
             p_sep   TYPE c DEFAULT ','.

AT SELECTION-SCREEN ON p_tname.
  IF p_tname NS '/PWEAVER/'.
    MESSAGE text-002 TYPE 'E'.
  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_fname.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
*  EXPORTING
*    WINDOW_TITLE            =
*    DEFAULT_EXTENSION       =
*    DEFAULT_FILENAME        =
*    FILE_FILTER             =
*    WITH_ENCODING           =
*    INITIAL_DIRECTORY       =
*    MULTISELECTION          =
    CHANGING
      file_table              = gt_filename
      rc                      = gv_return
*    USER_ACTION             =
*    FILE_ENCODING           =
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5
          .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ELSE.
    READ TABLE gt_filename INTO p_fname INDEX 1.
  ENDIF.

START-OF-SELECTION.

  TRY.
      CREATE DATA : gr_tab TYPE STANDARD TABLE OF (p_tname),
                    gr_wa  TYPE (p_tname).
    CATCH cx_sy_create_data_error.
      MESSAGE text-003 TYPE 'E'.
  ENDTRY.

  ASSIGN : gr_tab->* TO <gfs_table>,
           gr_wa->* TO <gfs_wa>.

  CALL METHOD cl_gui_frontend_services=>gui_upload
    EXPORTING
      filename                = p_fname
      filetype                = 'ASC'
*      has_field_separator     = 'X'
*    HEADER_LENGTH           = 0
*    READ_BY_LINE            = 'X'
*    DAT_MODE                = SPACE
*    CODEPAGE                = SPACE
*    IGNORE_CERR             = ABAP_TRUE
*    REPLACEMENT             = ','
*    VIRUS_SCAN_PROFILE      =
*  IMPORTING
*    FILELENGTH              =
*    HEADER                  =
    CHANGING
      data_tab                = gt_rawdata
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      OTHERS                  = 19
          .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  LOOP AT gt_rawdata INTO gs_rawdata FROM p_dasl.

    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE <gfs_wa> TO <gfs_field>.
      IF sy-subrc <> 0 OR gs_rawdata IS INITIAL.
        EXIT.
      ENDIF.
      IF sy-index = 1.
        <gfs_field> = sy-mandt.
      ELSE.
        TRY.
            CALL METHOD cl_abap_typedescr=>describe_by_data
              EXPORTING
                p_data      = <gfs_field>
              RECEIVING
                p_descr_ref = go_type.
            CLEAR gv_strfield.
            SPLIT gs_rawdata AT p_sep INTO gv_strfield gs_rawdata.
            IF go_type IS BOUND AND go_type->type_kind = cl_abap_typedescr=>typekind_date AND gv_strfield IS NOT INITIAL.
              CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
                EXPORTING
                 date_external                  = gv_strfield
*                  ACCEPT_INITIAL_DATE            =
               IMPORTING
                 date_internal                  = gv_strfield
               EXCEPTIONS
                 date_external_is_invalid       = 1
                 OTHERS                         = 2
                        .
              IF sy-subrc <> 0.
                MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
              ENDIF.

            ENDIF.
            <gfs_field> = gv_strfield.
          CATCH cx_dynamic_check.
            CONTINUE.
        ENDTRY.
      ENDIF.
    ENDDO.
    IF <gfs_wa> IS ASSIGNED.
      APPEND <gfs_wa> TO <gfs_table>.
      CLEAR <gfs_wa>.
    ENDIF.
  ENDLOOP.
  IF p_prvw = abap_true.
    PERFORM preview_data USING <gfs_table>.
  ENDIF.

  IF p_refr = abap_true.
    DELETE FROM (p_tname).
    COMMIT WORK.
  ENDIF.
  IF p_updt = abap_true.
    MODIFY (p_tname) FROM TABLE <gfs_table>.
  ENDIF.
*&---------------------------------------------------------------------*
*&      Form  preview_data
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_<GFS_TABLE>  text
*----------------------------------------------------------------------*
FORM preview_data  USING  p_gfs_table TYPE STANDARD TABLE.

  DATA : lo_table TYPE REF TO cl_salv_table.

  TRY.
      CALL METHOD cl_salv_table=>factory
*      EXPORTING
*        list_display   = IF_SALV_C_BOOL_SAP=>FALSE
*        r_container    =
*        container_name =
        IMPORTING
          r_salv_table   = lo_table
        CHANGING
          t_table        = p_gfs_table
          .
    CATCH cx_salv_msg .
  ENDTRY.
  IF lo_table IS BOUND.
    lo_table->display( ).
  ENDIF.

ENDFORM.                    " preview_data
