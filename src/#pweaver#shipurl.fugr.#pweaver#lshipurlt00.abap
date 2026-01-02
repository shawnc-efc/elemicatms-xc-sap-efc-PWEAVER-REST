*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /PWEAVER/SHIPURL................................*
DATA:  BEGIN OF STATUS_/PWEAVER/SHIPURL              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_/PWEAVER/SHIPURL              .
CONTROLS: TCTRL_/PWEAVER/SHIPURL
            TYPE TABLEVIEW USING SCREEN '9000'.
*.........table declarations:.................................*
TABLES: */PWEAVER/SHIPURL              .
TABLES: /PWEAVER/SHIPURL               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
