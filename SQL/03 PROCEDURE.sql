REPLACE PROCEDURE PE_DESA_REG_STAGE.SP_MTC_IDENTIFICA_LINEAS()

BEGIN

/* =====================================================================================================#
# Creado por         : INDRA                                                                            #
# Descripcion        : Genera Reporte Biometrico para Osiptel                                           #
# Parametros         : Fecha Inicio, Fecha Fin                                                          #
# ------------------------------------------------------------------------------------------------------#
# Ver Fecha        Usuario                       Proyecto                          Observacion          #
# ------------------------------------------------------------------------------------------------------#
# I1  12/08/2025   femurillo      Version Inicial                                 Version 1             # 
# ======================================================================================================#
*/

/* PRINCIPALES */
DECLARE vSQL VARCHAR(30000);
DECLARE vSQLCode INTEGER;
DECLARE vTabla VARCHAR(100);

/* ESQUEMA AMBIENTE */
DECLARE INH_STAGE VARCHAR(50) DEFAULT 'PE_DESA_REG_STAGE';
DECLARE INH_DATA VARCHAR(50) DEFAULT 'PE_DESA_REG_DATA';
DECLARE ESL_VIEW VARCHAR(50) DEFAULT 'PE_PROD_ESL_VIEW'; 
DECLARE FG_CONFIG VARCHAR(30) DEFAULT 'PE_REG_D_FG_CONFIG';

/* CODIGO DE SP */
DECLARE vSTORED VARCHAR(50);

/* VARIABLES */
/*DECLARE vFecIni VARCHAR(8);
DECLARE vFecFin VARCHAR(8); 
Declare vFECHAINI VARCHAR(8);
Declare vFECHAFIN VARCHAR(8);*/
/* CONTROL DE TIEMPO DEL SP */
 DECLARE EXIT HANDLER 
FOR SqlException 
BEGIN
    SET vSQLCode = SqlCode; 
    CALL PE_REG_D_FG_CONFIG.SP_LOG_CARGA('U', vSTORED, '4_ERROR', NULL, NULL, vSQLCode);
END; 

/* ASIGNACION DE VALORES A VARIABLES */
--SET vFECHAINI = pFecIni;
--SET vFECHAFIN =  pFecFin; 
 
SET vSTORED = 'MTCIDENLINEA';

--------------------------------------------------------------------------------------------------------------------------------------------
--- REGISTRANDO EL LOG DEL STORED
--------------------------------------------------------------------------------------------------------------------------------------------
CALL PE_REG_D_FG_CONFIG.SP_LOG_CARGA('I', vSTORED, '4_PROC', NULL, NULL, NULL);

-- =============================================
-- Obtener el subscriptor asociado al telefono fijo o movil
SET vTabla = 'TMP_EM_MTCIDENLINEA_002';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
SELECT a.numero_telefonico
     , dos.customer_key
     , subscriber_key
     , original_activation_date
     , dos.activation_date
     , dos.subscriber_status_date
     , dos.subscriber_status_key
     , s.subscriber_status_desc
     , cinco.address_key direccion
     , CASE 
           WHEN dos.lob_type = ''WRLS'' THEN ''movil''
           WHEN dos.lob_type = ''VOIC'' THEN ''fija''
       END tipo_plan
     , CASE 
           WHEN seis.customer_type_id = ''C'' THEN ''ruc'' 
           ELSE NVL(ocho.identification_1_type_code, nueve.identification_1_type_code) 
       END tipo_doc_id_amd
     , CASE 
           WHEN seis.customer_type_id = ''C'' THEN tres.rut_id 
           ELSE NVL(ocho.identification_document_1_numb, nueve.identification_document_1_numb) 
       END numero_doc_id_amd
     , CAST(CASE 
               WHEN seis.customer_type_id = ''C'' THEN tres.customer_legal_name 
               ELSE NVL(ocho.first_name, nueve.first_name) 
           END AS CHAR(150)) nombres_amd
     , CAST(CASE 
               WHEN seis.customer_type_id = ''C'' THEN '''' 
               ELSE NVL(ocho.last_name, nueve.last_name) 
           END AS CHAR(150)) apellidos_amd

FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_001 a
INNER JOIN PE_PROD_LZ_DATA.ALDM_SUBSCRIBER dos
    ON a.numero_telefonico = dos.primary_resource_value
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CUSTOMER tres 
    ON dos.customer_key = tres.customer_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CUSTOMER_SUB_TYPE seis 
    ON tres.customer_sub_type_key = seis.customer_sub_type_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CUSTOMER_CONTACT_REL siete 
    ON dos.customer_key = siete.customer_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CONTACT ocho 
    ON siete.contact_key = ocho.contact_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CONTACT nueve 
    ON nueve.contact_key = dos.contact_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_CONTACT cuatro 
    ON tres.crm_customer_main_contact_sour = cuatro.contact_key
LEFT JOIN PE_PROD_LZ_DATA.ALDM_ADDRESS cinco 
    ON cuatro.main_address_key = CAST(cinco.address_key AS DECIMAL(20, 0))
LEFT JOIN PE_PROD_LZ_DATA.ALDM_SUBSCRIBER_STATUS s 
    ON dos.subscriber_status_key = CAST(s.subscriber_status_key AS DECIMAL(20, 0))
) WITH DATA PRIMARY INDEX(numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Validar el producto asociado de los telefonos fijo
SET vTabla = 'TMP_EM_MTCIDENLINEA_TUPS_003';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT base.*
    FROM (
        SELECT a.subscriber_key
             , a.numero_telefonico
             , b.assigned_product_key
             , b.product_key
             , b.product_offer_key
             , b.service_type
             , b.start_date
             , b.end_date
             , b.assigned_product_status_key
             , b.assigned_product_state_key
             , ROW_NUMBER() OVER (
                   PARTITION BY a.subscriber_key, a.numero_telefonico
                   ORDER BY b.assigned_product_key DESC
               ) ord
        FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_002 a
        INNER JOIN PE_PROD_LZ_DATA.ALDM_ASSIGNED_PRODUCT b
            ON a.subscriber_key = b.subscriber_key
        WHERE b.service_type = ''VOIC''
          AND b.assigned_product_state_key = ''1097''
    ) base
    WHERE ord = 1
) WITH DATA PRIMARY INDEX(assigned_product_key, subscriber_key, numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Identificar si el fijo es producto es TUPS
SET vTabla = 'TMP_EM_MTCIDENLINEA_TUPS_004';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT a.subscriber_key
         , a.numero_telefonico
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_TUPS_003 a
    INNER JOIN PE_PROD_ESL_VIEW.VW_PRODUCT_CATALOG_PARAMS1 vw1
        ON vw1.product_catalog_key = a.product_offer_key
       AND vw1.product_parameter_name = ''Product Classification''
    INNER JOIN PE_PROD_ESL_VIEW.VW_PRODUCT_CATALOG_PARAMS1 vw
        ON vw.product_catalog_key = a.product_offer_key
       AND vw.product_parameter_name = ''Product''
       AND vw1.default_value IN (''TUPS'', ''TUPSPREP'')
) WITH DATA PRIMARY INDEX(subscriber_key, numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Obtener distrito , provincia y departamento de la direccion para moviles
SET vTabla = 'TMP_EM_MTCIDENLINEA_CATADDRESS_004';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT Distinct x.address_key
             , a.district_key
             , a.district_desc
             , b.city_desc
             , c.department_desc
        FROM PE_PROD_LZ_DATA.ALDM_ADDRESS x
        INNER JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_002 Y
            ON x.address_key = y.direccion
        LEFT JOIN PE_PROD_LZ_DATA.ALDM_DISTRICT a
            ON x.district_key = a.district_key
        LEFT JOIN PE_PROD_LZ_DATA.ALDM_CITY b
            ON a.city_key = b.city_key
        LEFT JOIN PE_PROD_LZ_DATA.ALDM_DEPARTMENT c
            ON b.department_key = c.department_key
) WITH DATA PRIMARY INDEX(subscriber_key, numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Consolidadr Informacion
-- Formatear documento, a?adir direccion fija y movil
-- a?adir si es tups o no
SET vTabla = 'TMP_EM_MTCIDENLINEA_005';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS  
(
    SELECT a.numero_telefonico
         , a.fecha
         , a.customer_key
         , a.subscriber_key
         , a.original_activation_date
         , a.activation_date
         , a.subscriber_status_date
         , a.subscriber_status_key
         , a.subscriber_status_desc
         , a.direccion
         , a.tipo_plan
         , a.tipo_doc_id_amd
         , a.nombres_amd
         , a.apellidos_amd
         , CASE 
               WHEN a.tipo_doc_id_amd = ''C'' THEN LPAD(a.numero_doc_id_amd, 12, ''0'')
               WHEN a.tipo_doc_id_amd = ''DNI'' THEN LPAD(a.numero_doc_id_amd, 8, ''0'')
               WHEN a.tipo_doc_id_amd = ''RUC'' THEN LPAD(a.numero_doc_id_amd, 11, ''0'')
               WHEN a.tipo_doc_id_amd = ''P'' THEN LPAD(a.numero_doc_id_amd, 12, ''0'')
               ELSE a.numero_doc_id_amd
           END numero_documento
         , CASE 
               WHEN b.subscriber_key IS NOT NULL THEN ''SI''
               ELSE ''NO''
           END tups
         , dos.district_desc AS distrito
         , dos.city_desc AS provincia
         , dos.department_desc AS departamento
         , CASE 
               WHEN a.tipo_plan = ''FIJA'' THEN TRIM(d.dre_tip_cal_ati_cd) || '' '' || TRIM(d.dre_nom_cal_ds) || '' '' || TRIM(d.dre_num_cal_nu)
               ELSE c.address_line_1
           END || TRIM(COALESCE('', '' || dos.district_desc, ''''))
              || TRIM(COALESCE('', '' || dos.city_desc, ''''))
              || '' '' || TRIM(COALESCE(dos.department_desc, '''')) AS direccion_txt
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_002 a
    LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_TUPS_004 b
        ON a.subscriber_key = b.subscriber_key
    LEFT JOIN  PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_CATADDRESS_004 dos
        ON a.direccion = dos.address_key
    LEFT JOIN PE_PROD_LZ_DATA.ALDM_ADDRESS c
        ON a.direccion = c.address_key
    LEFT JOIN PE_PROD_LZ_DATA.SCDREC d
        ON a.direccion = d.dre_cod_dir_cd
) WITH DATA PRIMARY INDEX(numero_telefonico, subscriber_key)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Obtener datos del subscriptor asociado a la linea
SET vTabla = 'TMP_EM_MTCIDENLINEA_006';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT *
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_005
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY numero_telefonico
        ORDER BY original_activation_date DESC, subscriber_status_date DESC, activation_date DESC
    ) = 1
) WITH DATA PRIMARY INDEX(numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Obtener datos los subscriptores anteriores asociado a la linea del mismo cliente
SET vTabla = 'TMP_EM_MTCIDENLINEA_007';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT a.*
         , COALESCE(b.subscriber_key, a.subscriber_key) subscriber_key_ant
         , b.subscriber_status_date subscriber_status_date_ant
         , b.subscriber_status_key subscriber_status_key_ant
         , CASE 
               WHEN b.subscriber_key IS NOT NULL THEN ''SI''
               ELSE ''NO''
           END tiene_ant
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_006 a
    LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_005 b
        ON a.numero_telefonico = b.numero_telefonico
       AND a.original_activation_date = b.original_activation_date 
    WHERE 1 = 1 
) WITH DATA PRIMARY INDEX(numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Obtener ordenes de bajas y alta por reinstalacion (Escenario de Suspension Llamali)
SET vTabla = 'TMP_EM_MTCIDENLINEA_ORDENES_008';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT x.numero_telefonico
         , a.subscriber_key
         , a.customer_key
         , a.order_action_key
         , a.order_key
         , c.order_item_type_desc
         , c.order_action_type_id
         , b.order_start_date
         , a.order_action_start_date
         , a.order_action_completed_date
         , a.order_action_status_date
         , a.reason_free_text
         , a.order_action_reason_key
         , d.order_action_reason_desc
     --    , a.order_sales_channel_key
      --   , e.sales_channel_name
    FROM PE_PROD_LZ_DATA.ALDM_ORDER_ACTION a
    INNER JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_002 x
        ON a.subscriber_key = x.subscriber_key
    INNER JOIN PE_PROD_LZ_DATA.ALDM_ODS_ORDER b
        ON a.order_key = b.order_key
    INNER JOIN PE_PROD_ESL_VIEW.VW_ALDM_ORDERACTIONTYPE c
        ON a.order_action_type_key = c.order_action_type_key
    LEFT JOIN PE_PROD_ESL_VIEW.VW_ALDM_ORDERACTIONREASON d
        ON a.order_action_reason_key = d.order_action_reason_key
  --  LEFT JOIN PE_PROD_ESL_VIEW.VW_ALDM_SALESSERVICECHANNEL e
   --     ON a.order_sales_channel_key = e.sales_service_channel_key
    WHERE 1 = 1
      AND b.order_status_key = ''1384''
      AND a.order_action_status_key = ''1426''
      AND c.order_action_type_id IN (''CE'', ''ES'')
) WITH DATA PRIMARY INDEX(numero_telefonico, subscriber_key, order_action_key)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- A?adir el detalle de ordenes a la informacion del subscriptor
SET vTabla = 'TMP_EM_MTCIDENLINEA_009';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
(
    SELECT tiene_ant
         , b.subscriber_status_desc
         , a.*
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_ORDENES_008 a
    INNER JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_007 b
        ON a.subscriber_key = b.subscriber_key_ant
       AND a.customer_key = b.customer_key
) WITH DATA PRIMARY INDEX(numero_telefonico, subscriber_key, order_action_key)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Cruzar la informacion con el reporte de Llamali para identificar las suspensiones
-- Regla: Solo se consideran las suspensiones que tienen una orden de baja (CE) en la misma fecha de inicio de suspension
-- En caso la suspension de llamali no tenga una orden de baja (CE) en la misma fecha, se deja nulo los campos de baja,sunpension y activacion
-- Los datos que se tienen en la fuente de llamali se priorizan
-- Se marca con flag_llamali = 'SI'
SET vTabla = 'TMP_EM_MTCIDENLINEA_010';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
    SELECT DISTINCT 
           a.numero_telefonico
         , tups
         , TRIM(b.nombre_titular) nombre_titular
         , CASE 
               WHEN b.tipo_documento = ''D'' THEN ''DNI''
               WHEN b.tipo_documento = ''R'' THEN ''RUC''
               WHEN b.tipo_documento = ''C'' THEN ''CE''
               ELSE b.tipo_documento
           END tipo_documento
         , a.numero_documento
         , OREPLACE(a.direccion_txt, '',,,,,'', '','') direccion
         , CAST(a.original_activation_date AS DATE) fecha_alta
         , CASE 
               WHEN a.subscriber_status_desc = ''Active'' THEN ''ACTIVO''
               WHEN LOWER(a.subscriber_status_desc) LIKE ''%sus%'' THEN ''SUSPENDIDO''
               ELSE ''BAJA''
           END estado_actual
         , CAST(subscriber_status_date AS DATE) fecha_estado_actual
         , CASE 
               WHEN c.order_action_start_date IS NOT NULL THEN CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE)
           END fecha_de_baja
         , CASE 
               WHEN c.order_action_start_date IS NOT NULL THEN CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE)
           END fecha_de_suspension
         , CASE 
               WHEN c.order_action_start_date IS NOT NULL THEN CAST(TO_DATE(b.fecha_fin_suspencion, ''DDMMYYYY'') AS DATE)
           END fecha_termino_suspension
         , CASE 
               WHEN c.order_action_start_date IS NOT NULL THEN CAST(TO_DATE(b.fecha_reactivacion_suspencion, ''DDMMYYYY'') AS DATE)
           END fecha_de_reactivacion
         , c.order_action_start_date
         , c.order_action_key
         , c.order_key
         , CAST(c.order_action_start_date AS DATE) - CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) dias_baja
         , ''SI'' flag_llamali
    FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_007 a
    INNER JOIN PE_PROD_REG_DATA.T_LLAMAL_OUT_RUREPORTE_D b
        ON a.numero_telefonico = b.numero_telefonico
       AND a.numero_documento = b.numero_documento
       AND COALESCE(b.fecha_inicio_suspencion, '''') <> ''''
    LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_009 c
        ON a.numero_telefonico = c.numero_telefonico
       AND CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) = CAST(c.order_action_start_date AS DATE)
       AND c.order_action_type_id = ''CE''
) WITH DATA PRIMARY INDEX(numero_telefonico)';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Eliminar si un telefono tiene fecha de suspension nula y existe otro registro con fecha de suspension no nula
 
SET vSQL = 'DELETE FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010
WHERE fecha_de_suspension IS NULL
  AND numero_telefonico IN (
      SELECT numero_telefonico 
      FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 b
      WHERE b.fecha_de_suspension IS NOT NULL
  )';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

/*Insertar los telefonos que no tienen una orden de baja (CE) luego de 1 a 5 d?as 
    de la fecha de inicio de suspensi?n de Llamali, o no tienen una fecha de suspensi?n
    El objetivo es compartir en otro bae esos casos
Se marca como flag_llamali = 'OB'
*/
SET vTabla = 'TMP_EM_MTCIDENLINEA_010';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
CREATE TABLE  ' || INH_STAGE || '.' || vTabla || ' AS
SELECT DISTINCT 
       a.numero_telefonico
     , a.tups
     , TRIM(b.nombre_titular) nombre_titular
     , CASE 
           WHEN b.tipo_documento = ''D'' THEN ''DNI''
           WHEN b.tipo_documento = ''R'' THEN ''RUC''
           WHEN b.tipo_documento = ''C'' THEN ''CE''
           ELSE b.tipo_documento
       END tipo_documento
     , a.numero_documento
     , OREPLACE(a.direccion_txt, '',,,,,'', '','') direccion
     , CAST(a.original_activation_date AS DATE) fecha_alta
     , CASE 
           WHEN a.subscriber_status_desc = ''Active'' THEN ''ACTIVO''
           WHEN LOWER(a.subscriber_status_desc) LIKE ''%sus%'' THEN ''SUSPENDIDO''
           ELSE ''BAJA''
       END estado_actual
     , CAST(subscriber_status_date AS DATE) fecha_estado_actual
     , CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) fecha_de_baja
     , CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) fecha_de_suspension
     , CAST(TO_DATE(b.fecha_fin_suspencion, ''DDMMYYYY'') AS DATE) fecha_termino_suspension
     , CAST(TO_DATE(b.fecha_reactivacion_suspencion, ''DDMMYYYY'') AS DATE) fecha_de_reactivacion
     , c.order_action_start_date
     , c.order_action_key
     , c.order_key
     , CAST(c.order_action_start_date AS DATE) - CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) dias_baja
     , ''OB'' Existe_llamali
FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_007 a
INNER JOIN PE_PROD_REG_DATA.T_LLAMAL_OUT_RUREPORTE_D b
    ON a.numero_telefonico = b.numero_telefonico
   AND a.numero_documento = b.numero_documento
   AND COALESCE(b.fecha_inicio_suspencion, '''') <> ''''
LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_009 c
    ON a.numero_telefonico = c.numero_telefonico
   AND CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) BETWEEN CAST(c.order_action_start_date AS DATE) - 5
                                                                   AND CAST(c.order_action_start_date AS DATE)
   AND c.order_action_type_id = ''CE''
LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 d
    ON a.numero_telefonico = d.numero_telefonico
   AND CAST(TO_DATE(b.fecha_inicio_suspencion, ''DDMMYYYY'') AS DATE) = d.fecha_de_suspension
   AND COALESCE(d.dias_baja, 1) = 0
WHERE d.numero_telefonico IS NULL';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);

-- Se insertar los registros que no existen en la tabla historica de llamali
-- Para estos registros no se coloca fecha de baja,suspension y activacion
SET vTabla = 'TMP_EM_MTCIDENLINEA_010';
CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE, vTabla, 'D', '');
SET vSQL = '
INSERT INTO PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 
(
    numero_telefonico, tups, nombre_titular, tipo_documento, numero_documento,
    direccion, fecha_alta, estado_actual, fecha_estado_actual, flag_llamali
)
SELECT DISTINCT 
       a.numero_telefonico
     , b.tups
     , TRIM(b.nombres_amd) || '' '' || TRIM(b.apellidos_amd) nombre_titular
     , b.tipo_doc_id_amd tipo_documento
     , b.numero_documento
     , OREPLACE(direccion_txt, '',,,,,'', '','') direccion_txt
     , CAST(b.original_activation_date AS DATE) fecha_alta
     , CASE 
           WHEN b.subscriber_status_desc = ''Active'' THEN ''ACTIVO''
           WHEN LOWER(b.subscriber_status_desc) LIKE ''%sus%'' THEN ''SUSPENDIDO''
           WHEN b.subscriber_status_desc IS NOT NULL THEN ''BAJA''
       END estado_actual
     , CAST(subscriber_status_date AS DATE) fecha_estado_actual
     , ''NO'' Existe_llamali
FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_001 a
LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_007 b
    ON a.numero_telefonico = b.numero_telefonico
LEFT JOIN PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 c
    ON a.numero_telefonico = c.numero_telefonico
WHERE c.numero_telefonico IS NULL';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);
 
--Insertar en tabla historica
SET vTabla = 'T_MTCIDENLINEA_H'; 
SET vSQL = 'INSERT INTO '|| INH_DATA || '.' || vTabla || '
SELECT CURRENT_TIMESTAMP(0) AS fecha_carga,
A.*
FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 A
';

INSERT INTO PE_REG_D_FG_CONFIG.LOGS_SPS_DETAILS VALUES(vSTORED, 2, CURRENT_TIMESTAMP, vSQL);
CALL DBC.SysExecSQL(vSQL);
/*
INSERT INTO PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 
SELECT   NUMERO_TELEFONICO,TUPS ES_TUPS, NOMBRE_TITULAR,TIPO_DOCUMENTO,NUMERO_DOCUMENTO,DIRECCION
FECHA_ALTA, ESTADO_ACTUAL,FECHA_ESTADO_ACTUAL,FECHA_DE_BAJA,FECHA_DE_SUSPENSION,FECHA_TERMINO_SUSPENSION 
,FECHA_DE_REACTIVACION 
  FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 
where flag_llamali <> 2
 ORDER BY ES_TUPS DESC,flag_llamali DESC,NUMERO_TELEFONICO,FECHA_DE_SUSPENSION  DESC

SELECT NUMERO_TELEFONICO,TUPS ES_TUPS, NOMBRE_TITULAR,TIPO_DOCUMENTO,NUMERO_DOCUMENTO,DIRECCION
FECHA_ALTA, ESTADO_ACTUAL,FECHA_ESTADO_ACTUAL,FECHA_DE_BAJA,FECHA_DE_SUSPENSION,FECHA_TERMINO_SUSPENSION 
,FECHA_DE_REACTIVACION ,ORDER_KEY, ORDER_ACTION_KEY, ORDER_ACTION_START_DATE,DIAS_BAJA DIAS_DESPUES
  FROM PE_DESA_REG_STAGE.TMP_EM_MTCIDENLINEA_010 
where flag_llamali = 2 ORDER BY ES_TUPS DESC,flag_llamali DESC,NUMERO_TELEFONICO,FECHA_DE_SUSPENSION  DESC
*/

---select fechainsercion,count(1) from PE_PROD_REG_DATA.T_LLAMAL_OUT_RUREPORTE_D  
  -----------------------------------------
  -- DEPURACION DE TEMPORALES
  -----------------------------------------

    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_001','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_002','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_TUPS_003','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_TUPS_004','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_005','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_006','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_007','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_ORDENES_008','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_009','D','');
    CALL PE_REG_D_FG_CONFIG.SP_TABLE_OPERATION(INH_STAGE,'TMP_EM_MTCIDENLINEA_010','D','');
    
  -----------------------------------------
  -- ACTUALIZANDO LOG
  -----------------------------------------
CALL PE_REG_D_FG_CONFIG.SP_LOG_CARGA('U',vSTORED,'4_FIN',NULL,NULL,NULL);

END;