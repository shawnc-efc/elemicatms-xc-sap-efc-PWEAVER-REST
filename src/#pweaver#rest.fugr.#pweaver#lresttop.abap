FUNCTION-POOL /PWEAVER/REST.                "MESSAGE-ID ..

* INCLUDE /PWEAVER/LRESTD...                 " Local class definition

*{   INSERT         ESRK940279                                        1
*&---------------------------------------------------------------------*
*&      Form  FLOWER_CLOSE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_LV_JSON_STRING  text
*----------------------------------------------------------------------*
FORM flower_open CHANGING json_string.
  IF json_string IS INITIAL.
    CONCATENATE '{' json_string INTO json_string.
  ELSE.
    CONCATENATE json_string '{' INTO json_string.
  ENDIF.
ENDFORM.
FORM flower_close CHANGING json_string.
  CONCATENATE json_string '}'  INTO json_string.
ENDFORM.
FORM flower_end CHANGING json_string.
  CONCATENATE json_string '},' INTO json_string.
ENDFORM.
FORM attb_1 USING p_str1
      p_str2
      p_str3
CHANGING json_string.

  CONCATENATE json_string '"' p_str1 '"' ':' '"' p_str2 '"' p_str3 INTO json_string.
ENDFORM.
FORM attb_2 USING p_str1 p_str2 CHANGING json_string.
  CONCATENATE json_string '"' p_str1 '"' p_str2 INTO json_string.
ENDFORM.
FORM array_close CHANGING json_string.
  CONCATENATE json_string ']' INTO json_string.
ENDFORM.
FORM array_end CHANGING json_string.
  CONCATENATE json_string '],' INTO json_string.
ENDFORM.
*}   INSERT
