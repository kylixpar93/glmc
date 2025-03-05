﻿create or replace package dev_cpm_invoice_pkg is

 PROCEDURE sync_invoice(p_data_id    NUMBER,
                         --out
                         x_status OUT VARCHAR2,
                         x_mess   OUT VARCHAR2,
                         x_detail OUT VARCHAR2);

end dev_cpm_invoice_pkg;
/
create or replace package body dev_cpm_invoice_pkg is

----------------------------------------
PROCEDURE Prc_Gen_Org(x_org_id          out number,
                        x_Org_Code        OUT VARCHAR2,
                        x_sob_id          out number,
                        x_Legal_Entity_Id OUT NUMBER) IS
    l_Org_Code        VARCHAR2(50);
    l_Legal_Entity_Id NUMBER;
    l_org_id          number;
    l_sob_id          number;
  BEGIN
    --
    SELECT Hou.Short_Code,
           Hou.Default_Legal_Context_Id,
           hou.organization_id,
           hou.set_of_books_id
      INTO l_Org_Code, l_Legal_Entity_Id, l_org_id, l_sob_id
      FROM Hr_Operating_Units Hou
     WHERE rownum = 1;
    --
    x_Org_Code        := l_Org_Code;
    x_Legal_Entity_Id := l_Legal_Entity_Id;
    x_org_id          := l_org_id;
    x_sob_id          := l_sob_id;
    --
  EXCEPTION
    WHEN OTHERS THEN
      x_Org_Code        := NULL;
      x_Legal_Entity_Id := NULL;
  END Prc_Gen_Org;
  FUNCTION get_next_invoice_number(p_org_id IN NUMBER) RETURN VARCHAR2 IS
    l_max_number NUMBER;
    l_string     VARCHAR2(60);
  
    l_new_number    NUMBER;
    l_output_string VARCHAR2(30);
  
  BEGIN
    l_string := LPAD(p_org_id, 4, '0');
    -- Tìm giá trị số lớn nhất trong my_column với cùng gl_date và attribute10
    BEGIN
      select max(to_number(substr(t.INVOICE_NUM,
                                  instr(t.INVOICE_NUM, '-') + 1)))
        into l_max_number
        from ap_invoices_all t
       where t.SOURCE = 'Manual Invoice Entry'
         and t.ORG_ID = p_org_Id;
    EXCEPTION
      WHEN OTHERS THEN
        l_max_number := NULL;
    END;
    -- Tăng giá trị số lớn nhất lên 1
    l_new_number := l_max_number + 1;
  
    -- Kết hợp lại thành chuỗi mới với số có 3 chữ số
    l_output_string := l_string || '-' || l_new_number;
  
    RETURN l_output_string;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_next_invoice_number;
  ----------------------------------------
procedure check_invoice(p_data_id number,
                           x_status  OUT VARCHAR2,
                           x_mess    OUT VARCHAR2,
                           x_detail  out varchar2) is
    l_supplierNum   VARCHAR2(500);
    l_supplierType  varchar2(200);
    l_Type          VARCHAR2(500);
    l_glDate        DATE;
    v_glDate        VARCHAR2(200);
    l_invoiceCur    VARCHAR2(500);
    l_invoiceAmount NUMBER;
    l_description   VARCHAR2(500);
    l_term          VARCHAR2(500);
  
    l_invoiceDFF           VARCHAR2(500);
    v_payDate              varchar2(200);
    v_payAmount            varchar2(200);
    v_bank_account_num     varchar2(200);
    v_payDescription       varchar2(500);
    v_bank_account_id      number;
    v_bank_account_name    varchar2(200);
    v_bank_acct_use_id     number;
    v_doc_sequence_id      number;
    v_payment_document_id  number;
    v_payment_profile_id   number;
    v_db_document_seq_name varchar2(200);
    v_sequence_name        varchar2(400);
    l_supplierSite         varchar2(200);
    v_invoiceDate          varchar2(200);
    l_exType               varchar2(200) := 'User';
    l_exRate               number;
    l_empCode              varchar2(200);
    l_empManager           varchar2(200);
    l_contract             varchar2(200);
    l_docNum               varchar2(200);
    l_project              varchar2(200);
    l_empType              varchar2(200);
    l_docNumCpm            varchar2(200);
    l_checkDocNumCpm       number;
    l_org_id               NUMBER;
    l_vendor_id            NUMBER;
    l_VENDOR_SITE_ID       NUMBER;
    v_liablity_cc_id       NUMBER;
    l_term_id              NUMBER;
    l_Sob_Id               NUMBER;
    v_isPayment            varchar2(200);
    v_Legal_Entity_Id      NUMBER;
    l_org_code             VARCHAR2(200);
    l_party_id             NUMBER;
    l_party_site_id        NUMBER;
    l_invoice_amount       NUMBER;
    l_sum_line_amount      NUMBER;
    v_check_gl             NUMBER;
    v_check_ap             NUMBER;
  
    l_coa_id NUMBER;
    --l_username       varchar2(200);
    l_segment1      varchar2(20);
    l_segment2      varchar2(20);
    l_segment3      varchar2(20);
    l_segment4      varchar2(20);
    l_check_segment number;
    v_segment1      varchar2(20);
    --v_segment2      varchar2(20);
    --v_segment3      varchar2(20);
    v_segment5      varchar2(20);
    v_segment6      varchar2(20);
    v_segment7      varchar2(20);
    v_segment8      varchar2(20);
    v_segment9      varchar2(20);
    v_segment10     varchar2(20);
    --v_segment11      varchar2(20);
    --c_segment2       varchar2(20);
    --c_segment3       varchar2(20);
    --c_segment4       varchar2(20);
    l_concat_seg varchar2(400);
    --v_check_ledger   number;
    v_check_currency number;
    ----
    l_return_status VARCHAR2(4000);
    l_return_mess   VARCHAR2(4000);
    l_return_detail varchar2(4000);
    I_Exception     Exception;
    l_applyAmount   number;
    --l_applyDate      varchar2(200);
    --l_appyPaymentNum varchar2(200);
    l_isApply       varchar2(1);
    l_check_preNum  number;
    l_Pre_vendor_id number;
  begin
    x_status := 'S';
   
  
    begin
      SELECT t.supplierNum,
             upper(t.Type),
             t.supplierSite,
             t.invoiceDate,
             t.description,
             t.invoiceCur,
             t.invoiceAmount,
             t.exType,
             decode(t.invoiceCur, 'VND', 1, t.exRate) exRate,
             t.glDate,
             t.invoiceDFF,
             t.empCode,
             t.empManager,
             t.contract,
             t.docNum,
             t.project,
             t.empType,
             t.docNumCpm,
             t.segment1,
             t.segment2,
             t.segment3,
             t.segment4
        INTO l_supplierNum,
             l_Type,
             l_supplierSite,
             v_invoiceDate,
             l_description,
             l_invoiceCur,
             l_invoiceAmount,
             l_exType,
             l_exRate,
             v_glDate,
             l_invoiceDFF,
             l_empCode,
             l_empManager,
             l_contract,
             l_docNum,
             l_project,
             l_empType,
             l_docNumCpm,
             l_segment1,
             l_segment2,
             l_segment3,
             l_segment4
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Invoice'
                        COLUMNS(supplierNum VARCHAR2(500) PATH
                                '$.supplierNum',
                                type VARCHAR2(500) PATH '$.type',
                                supplierSite varchar2(200) PATH
                                '$.supplierSite',
                                invoiceDate varchar2(200) path
                                '$.invoiceDate',
                                description varchar2(500) path
                                '$.description',
                                invoiceCur VARCHAR2(500) PATH '$.invoiceCur',
                                invoiceAmount NUMBER PATH '$.invoiceAmount',
                                exType varchar2(200) path '$.exType',
                                exRate number path '$.exRate',
                                glDate VARCHAR2(500) PATH '$.glDate',
                                invoiceDFF VARCHAR2(500) PATH '$.invoiceDFF',
                                empCode VARCHAR2(500) PATH '$.empCode',
                                empManager VARCHAR2(500) PATH '$.empManager',
                                contract VARCHAR2(500) PATH '$.contract',
                                docNum VARCHAR2(500) PATH '$.docNum',
                                project VARCHAR2(500) PATH '$.project',
                                empType VARCHAR2(200) PATH '$.empType',
                                docNumCpm varchar2(200) path '$.docNumCpm',
                                segment1 varchar2(200) path '$.segment1',
                                segment2 varchar2(200) path '$.segment2',
                                segment3 varchar2(200) path '$.segment3',
                                segment4 varchar2(200) path '$.segment4')) t
       WHERE j.data_id = p_data_id;
    EXCEPTION
      WHEN OTHERS THEN
      
        l_supplierNum   := null;
        l_Type          := null;
        l_description   := null;
        l_invoiceCur    := null;
        l_invoiceAmount := null;
        --l_exType        := null;
        --l_exRate        := null;
        v_glDate     := null;
        l_term       := null;
        l_invoiceDFF := null;
        --l_empCode       := null;
        --l_empManager    := null;
        --l_contract      := null;
        --l_docNum        := null;
        --l_project       := null;
        --l_empType       := null;
        l_docNumCpm := null;
        --l_segment1  := null;
        --l_segment2      := null;
      --l_segment3      := null;
      --l_segment4      := null;
    END;
  
    Prc_Gen_Org(l_org_id, l_org_code, l_sob_id, v_Legal_Entity_Id);
  
    l_coa_id := dev_cpm_prepay_pkg.get_coa_id(l_sob_id);
  
    BEGIN
      SELECT ap.VENDOR_ID, ap.VENDOR_TYPE_LOOKUP_CODE, ap.PARTY_ID
        INTO l_vendor_id, l_supplierType, l_party_id
        FROM ap_suppliers ap
       WHERE ap.ATTRIBUTE13 = l_supplierNum;
    EXCEPTION
      WHEN OTHERS THEN
        l_vendor_id := NULL;
        --l_party_id  := NULL;
    END;
    IF l_vendor_id IS NULL THEN
      l_return_status := 'E22PREB004';
      l_return_mess   := 'Nhà cung cấp không được bỏ trống!';
      l_return_detail := 'Nhà cung cấp chưa có trên hệ thống!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      begin
        select site.VENDOR_SITE_ID,
               site.ACCTS_PAY_CODE_COMBINATION_ID,
               site.PARTY_SITE_ID
          into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
          from ap_supplier_sites_all site
         where site.VENDOR_ID = l_vendor_id
           and upper(site.VENDOR_SITE_CODE) like 'T%';
      exception
        when others then
          --l_VENDOR_SITE_ID := NULL;
          v_liablity_cc_id := NULL;
          --l_party_site_id  := NULL;
      end;
    
    END IF;
    
    select gcc.SEGMENT5,
           gcc.SEGMENT6,
           gcc.segment7,
           gcc.SEGMENT8,
           gcc.SEGMENT9,
           gcc.SEGMENT10
      into v_segment5,
           v_segment6,
           v_segment7,
           v_segment8,
           v_segment9,
           v_segment10
      from gl_code_combinations gcc
     where gcc.CODE_COMBINATION_ID = v_liablity_cc_id;
    IF dev_cpm_api_pkg.is_date(v_glDate) = 'N' THEN
      l_return_status := 'E22PREV006';
      l_return_mess   := 'Ngày hạch toán không được để trống!';
      l_return_detail := 'Ngày hạch toán bắt buộc định dạng DD-MM-RRRR!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    ELSE
      l_glDate := to_date(v_glDate, 'DD-MM-RRRR');
    END IF;
  
    SELECT COUNT(*)
      INTO v_check_gl
      FROM GL_PERIOD_STATUSES gps
     WHERE gps.APPLICATION_ID = 101
       AND gps.SET_OF_BOOKS_ID = l_sob_id
       AND l_glDate BETWEEN gps.START_DATE AND gps.END_DATE
       AND gps.CLOSING_STATUS = 'O';
    IF v_check_gl = 0 THEN
      l_return_status := 'E22PREB007';
      l_return_mess   := 'Ngày hạch toán không thuộc kỳ GL!';
      l_return_detail := 'Ngày hạch toán không thuộc kỳ GL!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    SELECT COUNT(*)
      INTO v_check_ap
      FROM GL_PERIOD_STATUSES gps
     WHERE gps.APPLICATION_ID = 200
       AND gps.SET_OF_BOOKS_ID = l_sob_id
       AND l_glDate BETWEEN gps.START_DATE AND gps.END_DATE
       AND gps.CLOSING_STATUS = 'O';
    IF v_check_ap = 0 THEN
      l_return_status := 'E22PREB008';
      l_return_mess   := 'Ngày hạch toán không thuộc kỳ AP!';
      l_return_detail := 'Ngày hạch toán không thuộc kỳ AP!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    if l_type is null or l_type not in  ('STANDARD', 'DEBIT') then
      l_return_status := 'E22PREB009';
      l_return_mess   := 'Phân loại chứng từ không được để trống!';
      l_return_detail := 'Phân loại chứng từ phải là Standard hoặc Debit!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    end if;
    IF l_description IS NULL or lengthb(l_description) > 240 THEN
      l_return_status := 'E22PREV010';
      l_return_mess   := 'Diễn giải không được để trống!';
      l_return_detail := 'Diễn giải tối đa 240 ký tự!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    select count(*)
      into v_check_currency
      from fnd_currencies f
     where f.ENABLED_FLAG = 'Y'
       and f.CURRENCY_CODE = l_invoiceCur;
    IF l_invoiceCur IS NULL or v_check_currency = 0 THEN
      l_return_status := 'E22PREV011';
      l_return_mess   := 'Lỗi loại tiền!';
      l_return_detail := 'Loại tiền không được để trống hoặc không có trên hệ thống Oracle GL!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    IF l_invoiceAmount IS NULL THEN
      l_return_status := 'E22PREV012';
      l_return_mess   := 'Số tiền hoá đơn không được để trống!';
      l_return_detail := 'Số tiền hóa đơn phải có định dạng số!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    l_term := '1D';
    BEGIN
      SELECT at.TERM_ID
        INTO l_term_id
        FROM ap_terms at
       WHERE at.NAME = l_term;
    EXCEPTION
      WHEN OTHERS THEN
        l_term_id := NULL;
    END;
    IF l_term_id IS NULL THEN
      l_return_status := 'E22PREB014';
      l_return_mess   := 'Thời hạn thanh toán chưa có trên hệ thống!';
      l_return_detail := 'Thời hạn thanh toán chưa có trên hệ thống!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    BEGIN
      SELECT SUM(t.lineAmount) line_amount, t.invoiceAmount
        INTO l_sum_line_amount, l_invoice_amount
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Invoice'
                        COLUMNS(invoiceAmount NUMBER path '$.invoiceAmount',
                                NESTED PATH '$.InvoiceLine[*]'
                                COLUMNS(lineAmount NUMBER PATH '$.lineAmount'))) t
       WHERE j.data_id = p_data_id
       GROUP BY t.invoiceAmount;
    EXCEPTION
      WHEN OTHERS THEN
        l_sum_line_amount := NULL;
        l_invoice_amount  := NULL;
    END;
    IF l_sum_line_amount IS NULL THEN
      l_return_status := 'E22PREV015';
      l_return_mess   := 'Số tiền invoice line không được để trống!';
      l_return_detail := 'Số tiền invoice line phải là định dạng số!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    IF nvl(l_sum_line_amount, -1) <> nvl(l_invoice_amount, 0) THEN
      l_return_status := 'E22PREB016';
      l_return_mess   := 'Tổng tiền invoice line không bằng invoice header';
      l_return_detail := 'Tổng tiền invoice line không bằng invoice header';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    if l_invoiceDFF is null or lengthb(l_invoiceDFF) > 240 then
      l_return_status := 'E22PREV017';
      l_return_mess   := 'Thông tin bổ sung không được để trống!';
      l_return_detail := 'Thông tin bổ sung tối đa 240 ký tự!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    end if;
  
    select count(*)
      into l_checkDocNumCpm
      from ap_invoices_all ai
     where ai.ATTRIBUTE10 = l_docNumCpm;
    if l_docNumCpm is null then
      l_return_status := 'E22PREV024';
      l_return_mess   := 'Số chứng từ tham chiếu không đúng định dạng!';
      l_return_detail := 'Số chứng từ tham chiếu không được để trống!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      if l_checkDocNumCpm <> 0 then
        l_return_status := 'E22PREB025';
        l_return_mess   := 'Số chứng từ tham chiếu không đúng định dạng!';
        l_return_detail := 'Số chứng từ tham chiếu đã tồn tại trên hệ thống!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise I_Exception;
      end if;
    end if;
    
    FOR rec IN (SELECT upper(Type) invoiceType,
                       tO_date(t.glDate, 'DD-MM-RRRR') gldate,
                       lineamount,
                       lineDescription,
                       budget,
                       campaign,
                       fromDate,
                       toDate,
                       app,
                       partner,
                       customer,
                       employee,
                       segment1,
                       segment2,
                       segment3,
                       segment4,
                       segment5,
                       segment6,
                       segment7,
                       segment8,
                       segment9,
                       segment10,
                       segment11
                  FROM dev.dev_CPM_api_data j,
                       JSON_TABLE(j.json_data,
                                  '$.Invoice'
                                  COLUMNS(glDate VARCHAR2(500) PATH
                                          '$.glDate',
                                          invoiceAmount NUMBER path
                                          '$.invoiceAmount',
                                          Type VARCHAR2(200) PATH '$.type',
                                          NESTED PATH '$.InvoiceLine[*]'
                                          COLUMNS(lineAmount NUMBER PATH
                                                  '$.lineAmount',
                                                  lineDescription VARCHAR2(250) PATH
                                                  '$.lineDescription',
                                                  segment1 varchar2(200) path
                                                  '$.segment1',
                                                  segment2 varchar2(200) path
                                                  '$.segment2',
                                                  segment3 varchar2(200) path
                                                  '$.segment3',
                                                  segment4 varchar2(200) path
                                                  '$.segment4',
                                                  segment5 varchar2(200) path
                                                  '$.segment5',
                                                  segment6 varchar2(200) path
                                                  '$.segment6',
                                                  segment7 varchar2(200) path
                                                  '$.segment7',
                                                  segment8 varchar2(200) path
                                                  '$.segment8',
                                                  segment9 varchar2(200) path
                                                  '$.segment9',
                                                  segment10 varchar2(200) path
                                                  '$.segment10',
                                                  segment11 varchar2(200) path
                                                  '$.segment11',
                                                  budget varchar2(300) path
                                                  '$.budget',
                                                  campaign varchar2(300) path
                                                  '$.campaign',
                                                  fromDate varchar2(200) path
                                                  '$.fromDate',
                                                  toDate varchar2(300) path
                                                  '$.toDate',
                                                  app varchar2(200) path
                                                  '$.app',
                                                  partner varchar2(300) path
                                                  '$.partner',
                                                  customer varchar2(300) path
                                                  '$.customer',
                                                  employee varchar2(300) path
                                                  '$.employee'))) t
                 WHERE j.data_id = p_data_id) LOOP
    
      l_concat_seg := rec.segment1 || '.' || rec.segment2 || '.' ||
                      rec.segment3 || '.' || rec.segment11 || '.' ||
                      rec.segment5 || '.' ||rec.segment4 || '.' || 
                      rec.segment6 || '.' ||
                      rec.segment7 || '.' || rec.segment8 || '.' ||
                      rec.segment9 || '.' || rec.segment10;
      dev_cpm_api_pkg.check_ccid(p_coa_id     => l_coa_id,
                                 p_concat_seg => l_concat_seg,
                                 x_ccid       => l_check_segment,
                                 x_status     => l_return_status,
                                 x_mess       => l_return_mess,
                                 x_detail     => l_return_detail);
      if l_return_status <> 'S' then
        x_status := l_return_status;
        x_mess   := l_return_mess;
        x_detail := l_return_detail;
        raise I_Exception;
      end if;
    end loop;
    for tax in (select transNum,
                       transSymbol,
                       transDate,
                       itemName,
                       objectName,
                       objectTaxCode,
                       amtCcy,
                       amtTax,
                       amtLcy
                  FROM dev.dev_cpm_api_data j,
                       JSON_TABLE(j.json_data,
                                  '$.Invoice'
                                  COLUMNS(NESTED PATH '$.Tax[*]'
                                          COLUMNS(transNum varchar2(200) PATH
                                                  '$.transNum',
                                                  transSymbol varchar2(200) path
                                                  '$.transSymbol',
                                                  transDate varchar2(200) path
                                                  '$.transDate',
                                                  itemName varchar2(500) path
                                                  '$.itemName',
                                                  objectName VARCHAR2(500) PATH
                                                  '$.objectName',
                                                  objectTaxCode VARCHAR2(500) PATH
                                                  '$.objectTaxCode',
                                                  amtCcy NUMBER path
                                                  '$.amtCcy',
                                                  amtTax number path
                                                  '$.amtTax',
                                                  amtLcy number PATH
                                                  '$.amtLcy'))) t
                 WHERE j.data_id = p_data_id) loop
      if dev_cpm_api_pkg.is_date(tax.transDate) = 'N' then
        l_return_status := 'E22STAV025';
        l_return_mess   := 'Ngày hóa đơn không đúng định dạng!';
        l_return_detail := 'Ngày hóa đơn bắt buộc định dạng DD-MM-YYYY!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise I_Exception;
      
      end if;
    end loop;
    
  exception
    when I_Exception then
      null;
  end;
  -------------------------------------------------
  procedure create_invoice_batch(p_user_id  number,
                                 p_username varchar2,
                                 p_org_id   number,
                                 x_batch_id out number) is
    l_batch_name  varchar2(240);
    l_check_batch number;
    v_rowid       varchar2(2000);
  
  begin
    l_batch_name := p_username || '-' || to_char(sysdate, 'ddmmYYYY');
    begin
      select ab.BATCH_ID
        into l_check_batch
        from ap_batches_all ab
       where ab.BATCH_NAME = l_batch_name;
    exception
      when others then
        l_check_batch := 0;
    end;
    if l_check_batch <> 0 then
      x_batch_id := l_check_batch;
    else
      SELECT Ap_Batches_s.Nextval INTO l_check_batch FROM Dual;
      ap_batches_pkg.Insert_Row(X_Rowid                     => v_rowid,
                                X_Batch_Id                  => l_check_batch,
                                X_Batch_Name                => l_batch_name,
                                X_Batch_Date                => sysdate,
                                X_Last_Update_Date          => sysdate,
                                X_Last_Updated_By           => p_user_id,
                                X_Control_Invoice_Count     => null,
                                X_Control_Invoice_Total     => null,
                                X_Invoice_Currency_Code     => null,
                                X_Payment_Currency_Code     => null,
                                X_Last_Update_Login         => 0,
                                X_Creation_Date             => sysdate,
                                X_Created_By                => p_user_id,
                                X_Pay_Group_Lookup_Code     => null,
                                X_Payment_Priority          => null,
                                X_Batch_Code_Combination_Id => null,
                                X_Terms_Id                  => null,
                                X_Attribute1                => null,
                                X_Attribute2                => null,
                                X_Attribute3                => null,
                                X_Attribute4                => null,
                                X_Attribute_Category        => null,
                                X_Attribute5                => null,
                                X_Attribute6                => null,
                                X_Attribute7                => null,
                                X_Attribute8                => null,
                                X_Attribute9                => null,
                                X_Attribute10               => null,
                                X_Attribute11               => null,
                                X_Attribute12               => null,
                                X_Attribute13               => null,
                                X_Attribute14               => null,
                                X_Attribute15               => null,
                                X_Invoice_Type_Lookup_Code  => null,
                                X_Hold_Lookup_Code          => null,
                                X_Hold_Reason               => null,
                                X_Doc_Category_Code         => null,
                                X_Org_Id                    => p_org_id,
                                X_calling_sequence          => l_check_batch,
                                X_gl_date                   => sysdate);
      commit;
    end if;
  end;
  -----------------
  PROCEDURE create_invoice_header(p_data_id     NUMBER,
                                  p_user_id     number,
                                  x_invoice_id  OUT NUMBER,
                                  x_invoice_num OUT VARCHAR2,
                                  x_org_id      OUT NUMBER,
                                  x_batch_id    OUT NUMBER,
                                  x_status      OUT VARCHAR2,
                                  x_mess        OUT VARCHAR2,
                                  x_detail      out varchar2) IS
  
    l_supplierNum   VARCHAR2(500);
    l_supplierType  varchar2(200);
    l_Type          VARCHAR2(500);
    l_glDate        DATE;
    v_glDate        VARCHAR2(200);
    l_invoiceCur    VARCHAR2(500);
    l_invoiceAmount NUMBER;
    l_description   VARCHAR2(500);
    --l_term          VARCHAR2(500);
    l_termDate DATE;
    --v_termDate      VARCHAR2(200);
    l_invoiceDFF VARCHAR2(500);
  
    l_supplierSite varchar2(200);
    v_invoiceDate  varchar2(200);
  
    l_exType     varchar2(200) := 'User';
    l_exRate     number;
    l_empCode    varchar2(200);
    l_empManager varchar2(200);
    l_contract   varchar2(200);
    l_docNum     varchar2(200);
    l_project    varchar2(200);
    l_empType    varchar2(200);
    --l_checkEmpType   number;
    l_docNumCpm varchar2(200);
    --l_checkDocNumCpm number;
    l_org_id         NUMBER;
    l_vendor_id      NUMBER;
    l_VENDOR_SITE_ID NUMBER;
    v_liablity_cc_id NUMBER;
    --l_liablity_cc_id NUMBER;
    l_term_id     NUMBER;
    v_invoice_num VARCHAR2(300);
    v_batch_id    NUMBER;
    l_invoice_id  NUMBER;
    l_Sob_Id      NUMBER;
    v_h_Row_Id    VARCHAR2(500);
  
    v_resp_id         NUMBER := nvl(Apps.Fnd_Global.Resp_Id, 50738);
    v_resp_appl_id    NUMBER := nvl(apps.Fnd_Global.Resp_Appl_Id, 200);
    v_Legal_Entity_Id NUMBER;
    l_org_code        VARCHAR2(200);
    l_party_id        NUMBER;
    l_party_site_id   NUMBER;
    --l_invoice_amount  NUMBER;
    --l_sum_line_amount NUMBER;
    --v_check_gl        NUMBER;
    --v_check_ap        NUMBER;
  
    --l_coa_id        NUMBER;
    l_username varchar2(200);
    l_segment1 varchar2(20);
    l_segment2 varchar2(20);
    l_segment3 varchar2(20);
    l_segment4 varchar2(20);
    --l_check_segment number;
    --v_segment1      varchar2(20);
    --v_segment2      varchar2(20);
    --v_segment3      varchar2(20);
    --v_segment4      varchar2(20);
    --v_segment5      varchar2(20);
    --v_segment6      varchar2(20);
    --v_segment7      varchar2(20);
    --v_segment8      varchar2(20);
    --v_segment9      varchar2(20);
    --v_segment10     varchar2(20);
    --v_segment11     varchar2(20);
    --c_segment2      varchar2(20);
    --c_segment3      varchar2(20);
    --c_segment4      varchar2(20);
    --l_concat_seg    varchar2(40);
    ----
    --l_return_status VARCHAR2(4000);
    --l_return_mess   VARCHAR2(4000);
    --l_return_detail varchar2(4000);
  BEGIN
    Mo_Global.Init('SQLAP');
    x_status := 'S';
    Prc_Gen_Org(l_org_id, l_org_code, l_sob_id, v_Legal_Entity_Id);
    begin
      /*SELECT frv.responsibility_id
       into v_resp_id
       FROM apps.fnd_profile_options_vl       fpo,
            apps.fnd_profile_option_values    fpov,
            apps.fnd_responsibility_vl        frv,
            apps.per_security_organizations_v pers
      WHERE pers.organization_id = l_org_id
        AND fpov.level_value = frv.responsibility_id
        AND fpo.profile_option_id = fpov.profile_option_id
        AND fpo.user_profile_option_name = 'MO: Security Profile'
        AND fpov.profile_option_id = fpo.profile_option_id
        AND fpov.profile_option_value = pers.security_profile_id
        AND ROWNUM = 1;*/
      select frv.RESPONSIBILITY_ID
        into v_resp_id
        from fnd_responsibility_vl frv
       where frv.APPLICATION_ID = 200
         and frv.RESPONSIBILITY_KEY = 'AP_NHAP LIEU';
    exception
      when others then
        v_resp_id := null;
    end;
    v_resp_appl_id := 200;
    Apps.Fnd_Global.Apps_Initialize(User_Id      => p_User_Id,
                                    Resp_Id      => v_resp_id,
                                    Resp_Appl_Id => v_resp_appl_id);
    BEGIN
      SELECT t.supplierNum,
             upper(t.Type),
             t.supplierSite,
             t.invoiceDate,
             t.description,
             t.invoiceCur,
             t.invoiceAmount,
             t.exType,
             decode(t.invoiceCur, 'VND', 1, t.exRate) exRate,
             t.glDate,
             t.invoiceDFF,
             t.empCode,
             t.empManager,
             t.contract,
             t.docNum,
             t.project,
             t.empType,
             t.docNumCpm,
             t.segment1,
             t.segment2,
             t.segment3,
             t.segment4
        INTO l_supplierNum,
             l_Type,
             l_supplierSite,
             v_invoiceDate,
             l_description,
             l_invoiceCur,
             l_invoiceAmount,
             l_exType,
             l_exRate,
             v_glDate,
             l_invoiceDFF,
             l_empCode,
             l_empManager,
             l_contract,
             l_docNum,
             l_project,
             l_empType,
             l_docNumCpm,
             l_segment1,
             l_segment2,
             l_segment3,
             l_segment4
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Invoice'
                        COLUMNS(supplierNum VARCHAR2(500) PATH
                                '$.supplierNum',
                                type VARCHAR2(500) PATH '$.type',
                                supplierSite varchar2(200) PATH
                                '$.supplierSite',
                                invoiceDate varchar2(200) path
                                '$.invoiceDate',
                                description varchar2(500) path
                                '$.description',
                                invoiceCur VARCHAR2(500) PATH '$.invoiceCur',
                                invoiceAmount NUMBER PATH '$.invoiceAmount',
                                exType varchar2(200) path '$.exType',
                                exRate number path '$.exRate',
                                glDate VARCHAR2(500) PATH '$.glDate',
                                invoiceDFF VARCHAR2(500) PATH '$.invoiceDFF',
                                empCode VARCHAR2(500) PATH '$.empCode',
                                empManager VARCHAR2(500) PATH '$.empManager',
                                contract VARCHAR2(500) PATH '$.contract',
                                docNum VARCHAR2(500) PATH '$.docNum',
                                project VARCHAR2(500) PATH '$.project',
                                empType VARCHAR2(200) PATH '$.empType',
                                docNumCpm varchar2(200) path '$.docNumCpm',
                                segment1 varchar2(200) path '$.segment1',
                                segment2 varchar2(200) path '$.segment2',
                                segment3 varchar2(200) path '$.segment3',
                                segment4 varchar2(200) path '$.segment4')) t
       WHERE j.data_id = p_data_id;
    EXCEPTION
      WHEN OTHERS THEN
      
        l_supplierNum   := null;
        l_Type          := null;
        l_description   := null;
        l_invoiceCur    := null;
        l_invoiceAmount := null;
        l_exType        := null;
        l_exRate        := null;
        v_glDate        := null;
        --l_term          := null;
        l_invoiceDFF := null;
        --l_empCode       := null;
        --l_empManager    := null;
        --l_contract      := null;
        --l_docNum        := null;
        --l_project       := null;
        --l_empType       := null;
        l_docNumCpm := null;
        --l_segment1      := null;
      --l_segment2      := null;
      --l_segment3      := null;
      --l_segment4      := null;
    END;
  
    --l_coa_id := dev_cpm_prepay_pkg.get_coa_id(l_sob_id);
    begin
      select f.USER_NAME
        into l_username
        from fnd_user f
       where f.USER_ID = p_user_id;
    exception
      when others then
        l_username := null;
    end;
    BEGIN
      SELECT ap.VENDOR_ID, ap.VENDOR_TYPE_LOOKUP_CODE, ap.PARTY_ID
        INTO l_vendor_id, l_supplierType, l_party_id
        FROM ap_suppliers ap
       WHERE ap.ATTRIBUTE13 = l_supplierNum;
    EXCEPTION
      WHEN OTHERS THEN
        l_vendor_id := NULL;
        l_party_id  := NULL;
    END;
  
    begin
      select site.VENDOR_SITE_ID,
             site.ACCTS_PAY_CODE_COMBINATION_ID,
             site.PARTY_SITE_ID
        into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
        from ap_supplier_sites_all site
       where site.VENDOR_ID = l_vendor_id
         and upper(site.VENDOR_SITE_CODE) like 'T%';
    exception
      when others then
        l_VENDOR_SITE_ID := NULL;
        v_liablity_cc_id := NULL;
        l_party_site_id  := NULL;
    end;
    l_glDate      := to_date(v_glDate, 'DD-MM-RRRR');
    v_invoice_num := get_next_invoice_number(l_org_id);
  
    Mo_Global.Init('SQLAP');
    Apps.Fnd_Global.Apps_Initialize(User_Id      => p_User_Id, -- Apps.Fnd_Global.User_Id,
                                    Resp_Id      => v_Resp_Id, -- Apps.Fnd_Global.Resp_Id,
                                    Resp_Appl_Id => v_Resp_Appl_Id); -- Apps.Fnd_Global.Resp_Appl_Id);
  
    dev_cpm_prepay_pkg.create_invoice_batch(p_user_id  => p_user_id,
                                            p_username => l_username,
                                            p_org_id   => l_org_id,
                                            x_batch_id => v_batch_id);
    Ap_Ai_Table_Handler_Pkg.Insert_Row(p_Rowid                       => v_h_Row_Id,
                                       p_Invoice_Id                  => l_invoice_id,
                                       p_Last_Update_Date            => SYSDATE,
                                       p_Last_Updated_By             => p_user_id,
                                       p_Vendor_Id                   => l_Vendor_Id,
                                       p_Invoice_Num                 => v_invoice_num,
                                       p_Invoice_Amount              => l_invoiceAmount,
                                       p_Vendor_Site_Id              => l_Vendor_Site_Id,
                                       p_Amount_Paid                 => 0.00,
                                       p_Discount_Amount_Taken       => 0,
                                       p_Invoice_Date                => l_glDate,
                                       p_Source                      => 'Manual Invoice Entry',
                                       p_Invoice_Type_Lookup_Code    => l_Type,
                                       p_Description                 => l_description,
                                       p_Batch_Id                    => v_Batch_Id,
                                       p_Amt_Applicable_To_Discount  => l_invoiceAmount,
                                       p_Terms_Id                    => l_Term_Id,
                                       p_Terms_Date                  => l_termDate,
                                       p_Goods_Received_Date         => NULL,
                                       p_Invoice_Received_Date       => NULL,
                                       p_Voucher_Num                 => NULL,
                                       p_Approved_Amount             => l_invoiceAmount,
                                       p_Approval_Status             => NULL,
                                       p_Approval_Description        => NULL,
                                       p_Pay_Group_Lookup_Code       => Initcap(l_Type),
                                       p_Set_Of_Books_Id             => l_Sob_Id,
                                       p_Accts_Pay_Ccid              => v_liablity_cc_id,
                                       p_Recurring_Payment_Id        => NULL,
                                       p_Invoice_Currency_Code       => l_invoiceCur,
                                       p_Payment_Currency_Code       => l_invoiceCur,
                                       p_Exchange_Rate               => l_exRate,
                                       p_Payment_Amount_Total        => NULL,
                                       p_Payment_Status_Flag         => 'N',
                                       p_Posting_Status              => NULL,
                                       p_Authorized_By               => NULL,
                                       p_Attribute_Category          => l_invoiceDFF,
                                       p_Attribute1                  => null,
                                       p_Attribute2                  => null,
                                       p_Attribute3                  => null,
                                       p_Attribute4                  => null,
                                       p_Attribute5                  => null,
                                       p_Creation_Date               => SYSDATE,
                                       p_Created_By                  => p_user_id,
                                       p_Vendor_Prepay_Amount        => NULL,
                                       p_Base_Amount                 => NULL,
                                       p_Exchange_Rate_Type          => l_exType,
                                       p_Exchange_Date               => l_gldate,
                                       p_Payment_Cross_Rate          => 1,
                                       p_Payment_Cross_Rate_Type     => NULL,
                                       p_Payment_Cross_Rate_Date     => SYSDATE,
                                       p_Pay_Curr_Invoice_Amount     => l_invoiceAmount,
                                       p_Last_Update_Login           => NULL,
                                       p_Original_Prepayment_Amount  => NULL,
                                       p_Earliest_Settlement_Date    => sysdate,
                                       p_Attribute11                 => null,
                                       p_Attribute12                 => NULL,
                                       p_Attribute13                 => NULL,
                                       p_Attribute14                 => NULL,
                                       p_Attribute6                  => null,
                                       p_Attribute7                  => null,
                                       p_Attribute8                  => null,
                                       p_Attribute9                  => null,
                                       p_Attribute10                 => l_docNumCpm,
                                       p_Attribute15                 => null,
                                       p_Cancelled_Date              => NULL,
                                       p_Cancelled_By                => NULL,
                                       p_Cancelled_Amount            => NULL,
                                       p_Temp_Cancelled_Amount       => NULL,
                                       p_Exclusive_Payment_Flag      => 'N',
                                       p_Po_Header_Id                => NULL,
                                       p_Doc_Sequence_Id             => NULL,
                                       p_Doc_Sequence_Value          => NULL,
                                       p_Doc_Category_Code           => NULL,
                                       p_Expenditure_Item_Date       => NULL,
                                       p_Expenditure_Organization_Id => NULL,
                                       p_Expenditure_Type            => NULL,
                                       p_Pa_Default_Dist_Ccid        => NULL,
                                       p_Pa_Quantity                 => NULL,
                                       p_Project_Id                  => NULL,
                                       p_Task_Id                     => NULL,
                                       p_Awt_Flag                    => NULL,
                                       p_Awt_Group_Id                => NULL,
                                       p_Pay_Awt_Group_Id            => NULL,
                                       p_Reference_1                 => NULL,
                                       p_Reference_2                 => NULL,
                                       p_Org_Id                      => l_org_id,
                                       p_Global_Attribute_Category   => NULL,
                                       p_Global_Attribute1           => NULL,
                                       p_Global_Attribute2           => NULL,
                                       p_Global_Attribute3           => NULL,
                                       p_Global_Attribute4           => NULL,
                                       p_Global_Attribute5           => NULL,
                                       p_Global_Attribute6           => NULL,
                                       p_Global_Attribute7           => NULL,
                                       p_Global_Attribute8           => NULL,
                                       p_Global_Attribute9           => NULL,
                                       p_Global_Attribute10          => NULL,
                                       p_Global_Attribute11          => NULL,
                                       p_Global_Attribute12          => NULL,
                                       p_Global_Attribute13          => NULL,
                                       p_Global_Attribute14          => NULL,
                                       p_Global_Attribute15          => NULL,
                                       p_Global_Attribute16          => NULL,
                                       p_Global_Attribute17          => NULL,
                                       p_Global_Attribute18          => NULL,
                                       p_Global_Attribute19          => NULL,
                                       p_Global_Attribute20          => NULL,
                                       p_quick_credit                => 'N',
                                       p_taxation_country            => 'VN',
                                       p_force_revalidation_flag     => 'N',
                                       p_net_of_retainage_flag       => 'N',
                                       p_party_id                    => l_party_id,
                                       p_party_site_id               => l_party_site_id,
                                       p_Calling_Sequence            => To_Char(l_Invoice_Id),
                                       p_Gl_Date                     => l_GlDate,
                                       p_Award_Id                    => NULL,
                                       p_Approval_Iteration          => NULL,
                                       p_Approval_Ready_Flag         => 'Y',
                                       p_Wfapproval_Status           => 'NOT REQUIRED',
                                       p_Legal_Entity_Id             => v_Legal_Entity_Id,
                                       p_Payment_Method_Code         => 'CHECK');
    COMMIT;
  
    x_invoice_id  := l_invoice_id;
    x_invoice_num := v_invoice_num;
    x_org_id      := l_org_id;
    x_batch_id    := v_Batch_Id;
    IF l_invoice_id IS NOT NULL THEN
      x_status := 'S';
      x_mess   := 'Tạo dữ liệu invoice thành công!';
    END IF;
    dbms_output.put_line('l_invoice_id: ' || l_invoice_id);
  
  END create_invoice_header;
  ------------------
  PROCEDURE create_invoice_line(p_data_id    NUMBER,
                                p_user_id    number,
                                p_invoice_id NUMBER,
                                --
                                x_status OUT VARCHAR2,
                                x_mess   OUT VARCHAR2,
                                x_detail out varchar2) IS
  
    v_resp_id         NUMBER := nvl(Apps.Fnd_Global.Resp_Id, 50738);
    v_resp_appl_id    NUMBER := nvl(apps.Fnd_Global.Resp_Appl_Id, 200);
    v_Line_Num        NUMBER;
    v_l_Row_Id        VARCHAR2(500);
    v_d_Row_Id        VARCHAR2(500);
    v_Sob_Id          NUMBER; --:= applicationreport_pk.get_sob_id;
    l_org_id          NUMBER;
    v_coa_id          NUMBER;
    l_return_status   VARCHAR2(4000);
    l_return_mess     VARCHAR2(4000);
    v_Invoice_Dist_Id NUMBER;
    v_ccid_id         NUMBER;
    v_batch_id        NUMBER;
    v_liablity_cc_id  NUMBER;
    v_invoice_amount  NUMBER;
  
    v_concat_seg VARCHAR2(200);
    v_vendor_id  NUMBER;
    --v_prepay_cc_id NUMBER;
  
    v_vendor_site_id NUMBER;
    l_return_detail  varchar2(4000);
    -------
    v_segment1  varchar2(20);
    v_segment2  varchar2(20);
    v_segment3  varchar2(20);
    v_segment4  varchar2(20);
    v_segment5  varchar2(20);
    v_segment6  varchar2(20);
    v_segment7  varchar2(20);
    v_segment8  varchar2(20);
    v_segment9  varchar2(20);
    v_segment10 varchar2(20);
    v_segment11 varchar2(20);
  BEGIN
    x_status := 'S';
    Mo_Global.Init('SQLAP');
    BEGIN
      SELECT ai.BATCH_ID,
             ai.ACCTS_PAY_CODE_COMBINATION_ID,
             ai.INVOICE_AMOUNT,
             ai.VENDOR_ID,
             ai.SET_OF_BOOKS_ID,
             ai.ORG_ID,
             ai.VENDOR_SITE_ID
        INTO v_batch_id,
             v_liablity_cc_id,
             v_invoice_amount,
             v_vendor_id,
             v_Sob_Id,
             l_org_id,
             v_vendor_site_id
        FROM ap_invoices_all ai
       WHERE ai.INVOICE_ID = p_invoice_id;
    EXCEPTION
      WHEN OTHERS THEN
        v_batch_id       := NULL;
        v_liablity_cc_id := NULL;
        l_org_id         := NULL;
        v_Sob_Id         := NULL;
        --v_vendor_site_id := NULL;
    END;
    begin
      /*SELECT frv.responsibility_id
       into v_resp_id
       FROM apps.fnd_profile_options_vl       fpo,
            apps.fnd_profile_option_values    fpov,
            apps.fnd_responsibility_vl        frv,
            apps.per_security_organizations_v pers
      WHERE pers.organization_id = l_org_id
        AND fpov.level_value = frv.responsibility_id
        AND fpo.profile_option_id = fpov.profile_option_id
        AND fpo.user_profile_option_name = 'MO: Security Profile'
        AND fpov.profile_option_id = fpo.profile_option_id
        AND fpov.profile_option_value = pers.security_profile_id
        AND ROWNUM = 1;*/
      select frv.RESPONSIBILITY_ID
        into v_resp_id
        from fnd_responsibility_vl frv
       where frv.APPLICATION_ID = 200
         and frv.RESPONSIBILITY_KEY = 'AP_NHAP LIEU';
    exception
      when others then
        v_resp_id := null;
    end;
    v_resp_appl_id := 200;
    Apps.Fnd_Global.Apps_Initialize(User_Id      => p_user_id,
                                    Resp_Id      => v_resp_id,
                                    Resp_Appl_Id => v_resp_appl_id);
    v_Line_Num := 0;
  
    v_coa_id := dev_cpm_prepay_pkg.get_coa_id(v_sob_id);
  
    FOR rec IN (SELECT upper(Type) invoiceType,
                       tO_date(t.glDate, 'DD-MM-RRRR') gldate,
                       lineamount,
                       lineDescription,
                       budget,
                       campaign,
                       fromDate,
                       toDate,
                       app,
                       partner,
                       customer,
                       employee,
                       segment1,
                       segment2,
                       segment3,
                       segment4,
                       segment5,
                       segment6,
                       segment7,
                       segment8,
                       segment9,
                       segment10,
                       segment11
                  FROM dev.dev_CPM_api_data j,
                       JSON_TABLE(j.json_data,
                                  '$.Invoice'
                                  COLUMNS(glDate VARCHAR2(500) PATH
                                          '$.glDate',
                                          invoiceAmount NUMBER path
                                          '$.invoiceAmount',
                                          Type VARCHAR2(200) PATH '$.type',
                                          NESTED PATH '$.InvoiceLine[*]'
                                          COLUMNS(lineAmount NUMBER PATH
                                                  '$.lineAmount',
                                                  lineDescription VARCHAR2(250) PATH
                                                  '$.lineDescription',
                                                  segment1 varchar2(200) path
                                                  '$.segment1',
                                                  segment2 varchar2(200) path
                                                  '$.segment2',
                                                  segment3 varchar2(200) path
                                                  '$.segment3',
                                                  segment4 varchar2(200) path
                                                  '$.segment4',
                                                  segment5 varchar2(200) path
                                                  '$.segment5',
                                                  segment6 varchar2(200) path
                                                  '$.segment6',
                                                  segment7 varchar2(200) path
                                                  '$.segment7',
                                                  segment8 varchar2(200) path
                                                  '$.segment8',
                                                  segment9 varchar2(200) path
                                                  '$.segment9',
                                                  segment10 varchar2(200) path
                                                  '$.segment10',
                                                  segment11 varchar2(200) path
                                                  '$.segment11',
                                                  budget varchar2(300) path
                                                  '$.budget',
                                                  campaign varchar2(300) path
                                                  '$.campaign',
                                                  fromDate varchar2(200) path
                                                  '$.fromDate',
                                                  toDate varchar2(300) path
                                                  '$.toDate',
                                                  app varchar2(200) path
                                                  '$.app',
                                                  partner varchar2(300) path
                                                  '$.partner',
                                                  customer varchar2(300) path
                                                  '$.customer',
                                                  employee varchar2(300) path
                                                  '$.employee'))) t
                 WHERE j.data_id = p_data_id) LOOP
    
      v_concat_seg := rec.segment1 || '.' || rec.segment2 || '.' || rec.segment3 || '.' ||
                      rec.segment11 || '.' || rec.segment5 || '.' || rec.segment4 || '.' ||
                      rec.segment6 || '.' || rec.segment7 || '.' || rec.segment8 || '.' ||
                      rec.segment9 || '.' || rec.segment10;
    
      dev_cpm_api_pkg.check_ccid(p_coa_id     => v_coa_id,
                                 p_concat_seg => v_concat_seg,
                                 x_ccid       => v_ccid_id,
                                 x_status     => l_return_status,
                                 x_mess       => l_return_mess,
                                 x_detail     => l_return_detail);
    
      v_Line_Num := v_Line_Num + 1;
      Ap_Ail_Table_Handler_Pkg.Insert_Row(p_Rowid                        => v_l_Row_Id,
                                          p_Invoice_Id                   => p_invoice_id,
                                          p_Line_Number                  => v_Line_Num,
                                          p_Line_Type_Lookup_Code        => 'ITEM',
                                          p_Line_Group_Number            => NULL,
                                          p_Requester_Id                 => NULL,
                                          p_Description                  => rec.lineDescription,
                                          p_Line_Source                  => 'MANUAL LINE ENTRY',
                                          p_Org_Id                       => l_Org_Id,
                                          p_Inventory_Item_Id            => NULL,
                                          p_Item_Description             => NULL,
                                          p_Serial_Number                => NULL,
                                          p_Manufacturer                 => NULL,
                                          p_Model_Number                 => NULL,
                                          p_Warranty_Number              => NULL,
                                          p_Generate_Dists               => 'D',
                                          p_Match_Type                   => 'NOT_MATCHED',
                                          p_Distribution_Set_Id          => NULL,
                                          p_Account_Segment              => NULL,
                                          p_Balancing_Segment            => NULL,
                                          p_Cost_Center_Segment          => NULL,
                                          p_Overlay_Dist_Code_Concat     => NULL,
                                          p_Default_Dist_Ccid            => v_ccid_id,
                                          p_Prorate_Across_All_Items     => NULL,
                                          p_Accounting_Date              => rec.glDate,
                                          p_Period_Name                  => To_Char(rec.glDate,
                                                                                    'MM-YY'),
                                          p_Deferred_Acctg_Flag          => 'N',
                                          p_Def_Acctg_Start_Date         => NULL,
                                          p_Def_Acctg_End_Date           => NULL,
                                          p_Def_Acctg_Number_Of_Periods  => NULL,
                                          p_Def_Acctg_Period_Type        => NULL,
                                          p_Set_Of_Books_Id              => v_Sob_Id,
                                          p_Amount                       => rec.lineamount,
                                          p_Base_Amount                  => NULL,
                                          p_Rounding_Amt                 => NULL,
                                          p_Quantity_Invoiced            => NULL,
                                          p_Unit_Meas_Lookup_Code        => NULL,
                                          p_Unit_Price                   => NULL,
                                          p_Wfapproval_Status            => 'NOT REQUIRED',
                                          p_Discarded_Flag               => 'N',
                                          p_Original_Amount              => NULL,
                                          p_Original_Base_Amount         => NULL,
                                          p_Original_Rounding_Amt        => NULL,
                                          p_Cancelled_Flag               => 'N',
                                          p_Income_Tax_Region            => NULL,
                                          p_Type_1099                    => NULL,
                                          p_Stat_Amount                  => NULL,
                                          p_Prepay_Invoice_Id            => NULL,
                                          p_Prepay_Line_Number           => NULL,
                                          p_Invoice_Includes_Prepay_Flag => NULL,
                                          p_Corrected_Inv_Id             => NULL,
                                          p_Corrected_Line_Number        => NULL,
                                          p_Po_Header_Id                 => NULL,
                                          p_Po_Line_Id                   => NULL,
                                          p_Po_Release_Id                => NULL,
                                          p_Po_Line_Location_Id          => NULL,
                                          p_Po_Distribution_Id           => NULL,
                                          p_Rcv_Transaction_Id           => NULL,
                                          p_Final_Match_Flag             => NULL,
                                          p_Assets_Tracking_Flag         => 'N',
                                          p_Asset_Book_Type_Code         => NULL,
                                          p_Asset_Category_Id            => NULL,
                                          p_Project_Id                   => NULL,
                                          p_Task_Id                      => NULL,
                                          p_Expenditure_Type             => NULL,
                                          p_Expenditure_Item_Date        => NULL,
                                          p_Expenditure_Organization_Id  => NULL,
                                          p_Pa_Quantity                  => NULL,
                                          p_Pa_Cc_Ar_Invoice_Id          => NULL,
                                          p_Pa_Cc_Ar_Invoice_Line_Num    => NULL,
                                          p_Pa_Cc_Processed_Code         => NULL,
                                          p_Award_Id                     => NULL,
                                          p_Awt_Group_Id                 => NULL,
                                          p_Pay_Awt_Group_Id             => NULL,
                                          p_Reference_1                  => NULL,
                                          p_Reference_2                  => NULL,
                                          p_Receipt_Verified_Flag        => NULL,
                                          p_Receipt_Required_Flag        => NULL,
                                          p_Receipt_Missing_Flag         => NULL,
                                          p_Justification                => NULL,
                                          p_Expense_Group                => NULL,
                                          p_Start_Expense_Date           => NULL,
                                          p_End_Expense_Date             => NULL,
                                          p_Receipt_Currency_Code        => NULL,
                                          p_Receipt_Conversion_Rate      => NULL,
                                          p_Receipt_Currency_Amount      => NULL,
                                          p_Daily_Amount                 => NULL,
                                          p_Web_Parameter_Id             => NULL,
                                          p_Adjustment_Reason            => NULL,
                                          p_Merchant_Document_Number     => NULL,
                                          p_Merchant_Name                => NULL,
                                          p_Merchant_Reference           => NULL,
                                          p_Merchant_Tax_Reg_Number      => NULL,
                                          p_Merchant_Taxpayer_Id         => NULL,
                                          p_Country_Of_Supply            => NULL,
                                          p_Credit_Card_Trx_Id           => NULL,
                                          p_Company_Prepaid_Invoice_Id   => NULL,
                                          p_Cc_Reversal_Flag             => NULL,
                                          p_Creation_Date                => SYSDATE,
                                          p_Created_By                   => p_user_id,
                                          p_Last_Updated_By              => p_user_id,
                                          p_Last_Update_Date             => SYSDATE,
                                          p_Last_Update_Login            => NULL,
                                          p_Program_Application_Id       => NULL,
                                          p_Program_Id                   => NULL,
                                          p_Program_Update_Date          => NULL,
                                          p_Request_Id                   => NULL,
                                          p_Attribute_Category           => NULL,
                                          p_Attribute1                   => null,
                                          p_Attribute2                   => NULL,
                                          p_Attribute3                   => NULL,
                                          p_Attribute4                   => NULL,
                                          p_Attribute5                   => NULL,
                                          p_Attribute6                   => NULL,
                                          p_Attribute7                   => rec.campaign,
                                          p_Attribute8                   => rec.fromdate,
                                          p_Attribute9                   => rec.todate,
                                          p_Attribute10                  => rec.app,
                                          p_Attribute11                  => NULL,
                                          p_Attribute12                  => rec.partner,
                                          p_Attribute13                  => rec.customer,
                                          p_Attribute14                  => rec.employee,
                                          p_Attribute15                  => rec.budget,
                                          p_Calling_Sequence             => To_Char(p_Invoice_Id)
                                          --
                                          );
      SELECT Ap_Invoice_Distributions_s.Nextval
        INTO v_Invoice_Dist_Id
        FROM dual;
      dbms_output.put_line('v_Invoice_Dist_Id: ' || v_Invoice_Dist_Id);
      --
      Ap_Aid_Table_Handler_Pkg.Insert_Row(p_Rowid                       => v_d_Row_Id,
                                          p_Invoice_Id                  => p_Invoice_Id,
                                          p_Invoice_Line_Number         => v_Line_Num,
                                          p_Distribution_Class          => 'PERMANENT',
                                          p_Invoice_Distribution_Id     => v_Invoice_Dist_Id,
                                          p_Dist_Code_Combination_Id    => v_ccid_id,
                                          p_Last_Update_Date            => SYSDATE,
                                          p_Last_Updated_By             => p_user_id,
                                          p_Accounting_Date             => rec.glDate,
                                          p_Period_Name                 => To_Char(rec.glDate,
                                                                                   'MM-YY'),
                                          p_Set_Of_Books_Id             => v_Sob_Id,
                                          p_Amount                      => rec.lineamount,
                                          p_Description                 => rec.lineDescription,
                                          p_Type_1099                   => NULL,
                                          p_Posted_Flag                 => 'N',
                                          p_Batch_Id                    => v_batch_id,
                                          p_Quantity_Invoiced           => NULL,
                                          p_Unit_Price                  => NULL,
                                          p_Match_Status_Flag           => NULL,
                                          p_Attribute_Category          => NULL,
                                          p_Attribute1                  => NULL,
                                          p_Attribute2                  => NULL,
                                          p_Attribute3                  => NULL,
                                          p_Attribute4                  => NULL,
                                          p_Attribute5                  => NULL,
                                          p_Prepay_Amount_Remaining     => NULL,
                                          p_Assets_Addition_Flag        => 'N',
                                          p_Assets_Tracking_Flag        => 'N',
                                          p_Distribution_Line_Number    => 1,
                                          p_Line_Type_Lookup_Code       => 'ITEM',
                                          p_Po_Distribution_Id          => NULL,
                                          p_Base_Amount                 => NULL,
                                          p_Pa_Addition_Flag            => NULL,
                                          p_Posted_Amount               => NULL,
                                          p_Posted_Base_Amount          => NULL,
                                          p_Encumbered_Flag             => NULL,
                                          p_Accrual_Posted_Flag         => NULL,
                                          p_Cash_Posted_Flag            => NULL,
                                          p_Last_Update_Login           => NULL,
                                          p_Creation_Date               => SYSDATE,
                                          p_Created_By                  => p_user_id,
                                          p_Stat_Amount                 => NULL,
                                          p_Attribute11                 => NULL,
                                          p_Attribute12                 => NULL,
                                          p_Attribute13                 => NULL,
                                          p_Attribute14                 => NULL,
                                          p_Attribute6                  => NULL,
                                          p_Attribute7                  => NULL,
                                          p_Attribute8                  => NULL,
                                          p_Attribute9                  => NULL,
                                          p_Attribute10                 => NULL,
                                          p_Attribute15                 => NULL,
                                          p_Accts_Pay_Code_Comb_Id      => v_liablity_cc_id,
                                          p_Reversal_Flag               => 'N',
                                          p_Parent_Invoice_Id           => NULL,
                                          p_Income_Tax_Region           => NULL,
                                          p_Final_Match_Flag            => NULL,
                                          p_Expenditure_Item_Date       => NULL,
                                          p_Expenditure_Organization_Id => NULL,
                                          p_Expenditure_Type            => NULL,
                                          p_Pa_Quantity                 => NULL,
                                          p_Project_Id                  => NULL,
                                          p_Task_Id                     => NULL,
                                          p_Quantity_Variance           => NULL,
                                          p_Base_Quantity_Variance      => NULL,
                                          p_Packet_Id                   => NULL,
                                          p_Awt_Flag                    => NULL,
                                          p_Awt_Group_Id                => NULL,
                                          p_Pay_Awt_Group_Id            => NULL,
                                          p_Awt_Tax_Rate_Id             => NULL,
                                          p_Awt_Gross_Amount            => NULL,
                                          p_Reference_1                 => NULL,
                                          p_Reference_2                 => NULL,
                                          p_Org_Id                      => l_org_id,
                                          p_Other_Invoice_Id            => NULL,
                                          p_Awt_Invoice_Id              => NULL,
                                          p_Awt_Origin_Group_Id         => NULL,
                                          p_Program_Application_Id      => NULL,
                                          p_Program_Id                  => NULL,
                                          p_Program_Update_Date         => NULL,
                                          p_Request_Id                  => NULL,
                                          p_Tax_Recoverable_Flag        => NULL,
                                          p_Award_Id                    => NULL,
                                          p_Start_Expense_Date          => NULL,
                                          p_Merchant_Document_Number    => NULL,
                                          p_Merchant_Name               => NULL,
                                          p_Merchant_Tax_Reg_Number     => NULL,
                                          p_Merchant_Taxpayer_Id        => NULL,
                                          p_Country_Of_Supply           => NULL,
                                          p_Merchant_Reference          => NULL,
                                          p_Parent_Reversal_Id          => NULL,
                                          p_Rcv_Transaction_Id          => NULL,
                                          p_Matched_Uom_Lookup_Code     => NULL,
                                          p_Calling_Sequence            => To_Char(p_Invoice_Id)
                                          --
                                          );
      COMMIT;
    
    END LOOP; -- dữ liệu line
  END;
  ------
  PROCEDURE validate_invoice(p_data_id       NUMBER,
                             p_user_id       number,
                             p_org_id        NUMBER,
                             p_invoice_id    IN NUMBER,
                             x_return_status OUT VARCHAR2,
                             x_return_mess   OUT VARCHAR2,
                             x_return_detail out varchar2) IS
    v_resp_id            NUMBER;
    v_resp_appl_id       NUMBER;
    lx_holds_count       NUMBER;
    lx_approval_status   VARCHAR2(100);
    lv_funds_return_code VARCHAR2(100);
  
    ---
    l_invoice_number varchar2(200);
  
  BEGIN
    --
    x_return_status := 'S';
  
    --
  
    begin
      /*SELECT frv.responsibility_id
       into v_resp_id
       FROM apps.fnd_profile_options_vl       fpo,
            apps.fnd_profile_option_values    fpov,
            apps.fnd_responsibility_vl        frv,
            apps.per_security_organizations_v pers
      WHERE pers.organization_id = p_org_id
        AND fpov.level_value = frv.responsibility_id
        AND fpo.profile_option_id = fpov.profile_option_id
        AND fpo.user_profile_option_name = 'MO: Security Profile'
        AND fpov.profile_option_id = fpo.profile_option_id
        AND fpov.profile_option_value = pers.security_profile_id
        AND ROWNUM = 1;*/
      select frv.RESPONSIBILITY_ID
        into v_resp_id
        from fnd_responsibility_vl frv
       where frv.APPLICATION_ID = 200
         and frv.RESPONSIBILITY_KEY = 'AP_NHAP LIEU';
    
    exception
      when others then
        v_resp_id := null;
    end;
    v_resp_appl_id := 200;
  
    begin
      select ai.INVOICE_NUM
        into l_invoice_number
        from ap_invoices_all ai
       where ai.invoice_id = p_invoice_id;
    exception
      when others then
        l_invoice_number := null;
    end;
    mo_global.init('SQLAP');
    fnd_global.apps_initialize(p_user_id, v_resp_id, v_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
    mo_global.set_policy_context('S', p_org_id);
  
    ap_approval_pkg.approve(p_run_option         => 'ALL',
                            p_invoice_batch_id   => NULL,
                            p_begin_invoice_date => NULL,
                            p_end_invoice_date   => NULL,
                            p_vendor_id          => NULL,
                            p_pay_group          => NULL,
                            p_invoice_id         => p_invoice_id,
                            p_entered_by         => NULL,
                            p_set_of_books_id    => NULL,
                            p_trace_option       => NULL,
                            p_conc_flag          => NULL,
                            p_holds_count        => lx_holds_count,
                            p_approval_status    => lx_approval_status,
                            p_funds_return_code  => lv_funds_return_code,
                            p_calling_mode       => 'APPROVE',
                            p_calling_sequence   => 'CUXAPAUTOAPPLY',
                            p_debug_switch       => 'N',
                            p_budget_control     => 'Y',
                            p_commit             => 'Y');
    COMMIT;
    IF lx_approval_status IN ('APPROVED', 'AVAILABLE', 'UNPAID', 'FULL') THEN
      x_return_status := 'S';
      x_return_mess   := 'Validate invoice thành công!';
      x_return_detail := 'Validate invoice thành công!';
    ELSE
      x_return_status := 'E22PRES031';
      x_return_mess   := 'Lỗi validate invoice. Vượt ngân sách, đã tạo invoice và unc tại ORACLE! Cần kiểm tra Invoice Num: ' ||
                         l_invoice_number;
      x_return_detail := '';
    END IF;
  END validate_invoice;
  --------------
  PROCEDURE Create_Account(p_Application_Id  NUMBER,
                           p_Entity_Id       NUMBER,
                           p_Accounting_Mode VARCHAR2,
                           x_Return_Status   OUT VARCHAR2,
                           x_Return_Mess     OUT VARCHAR2) IS
    v_Entity_Id           NUMBER;
    v_Event_Source_Info   Xla_Events_Pub_Pkg.t_Event_Source_Info;
    x_Accounting_Batch_Id NUMBER;
    x_Errbuf              VARCHAR2(2000);
    x_Retcode             NUMBER;
    x_Request_Id          NUMBER;
  BEGIN
    ---set schema cho app
    Xla_Security_Pkg.Set_Security_Context(p_Application_Id);
    FOR Rec IN (SELECT *
                  FROM Xla.Xla_Transaction_Entities Xte
                 WHERE 1 = 1
                   AND Xte.Entity_Id = p_Entity_Id) LOOP
      v_Event_Source_Info.Source_Application_Id := Rec.Source_Application_Id;
      v_Event_Source_Info.Application_Id        := Rec.Application_Id;
      v_Event_Source_Info.Legal_Entity_Id       := Rec.Legal_Entity_Id;
      v_Event_Source_Info.Ledger_Id             := Rec.Ledger_Id;
      v_Event_Source_Info.Entity_Type_Code      := Rec.Entity_Code;
      v_Event_Source_Info.Transaction_Number    := Rec.Transaction_Number;
      v_Event_Source_Info.Source_Id_Int_1       := Rec.Source_Id_Int_1;
      v_Event_Source_Info.Source_Id_Int_2       := Rec.Source_Id_Int_2;
      v_Event_Source_Info.Source_Id_Int_3       := Rec.Source_Id_Int_3;
      v_Event_Source_Info.Source_Id_Int_4       := Rec.Source_Id_Int_4;
      v_Event_Source_Info.Source_Id_Char_1      := Rec.Source_Id_Char_1;
      v_Event_Source_Info.Source_Id_Char_2      := Rec.Source_Id_Char_3;
      v_Event_Source_Info.Source_Id_Char_3      := Rec.Source_Id_Char_3;
      v_Event_Source_Info.Source_Id_Char_4      := Rec.Source_Id_Char_4;
      v_Entity_Id                               := Rec.Entity_Id;
      Mo_Global.Set_Policy_Context('S', Rec.Security_Id_Int_1);
      Xla_Accounting_Pub_Pkg.Accounting_Program_Document(p_Event_Source_Info   => v_Event_Source_Info,
                                                         p_Application_Id      => 200,
                                                         p_Entity_Id           => v_Entity_Id,
                                                         p_Accounting_Flag     => 'Y',
                                                         p_Accounting_Mode     => p_Accounting_Mode,
                                                         p_Transfer_Flag       => 'N',
                                                         p_Gl_Posting_Flag     => 'N',
                                                         p_Offline_Flag        => 'N',
                                                         p_Accounting_Batch_Id => x_Accounting_Batch_Id, --out
                                                         p_Errbuf              => x_Errbuf, --out
                                                         p_Retcode             => x_Retcode, --out
                                                         p_Request_Id          => x_Request_Id --out
                                                         );
      IF x_Errbuf = 'Accounting Program completed Normal' THEN
        x_Return_Status := 'S';
        /*Elsif x_Errbuf =
            'Accounting Program completed Normal with some events in error' Then
        x_Return_Status := 'N';
        x_Return_Mess   := x_Errbuf || '(' || x_Request_Id || ')';*/
      ELSE
        x_Return_Status := 'E';
        x_Return_Mess   := x_Errbuf || '(' || x_Request_Id || ')';
        --dbms_output.put_line('bug:' || x_errbuf);
      END IF;
    END LOOP;
    COMMIT;
  END Create_Account;
  ----------------
  procedure create_tax_manual(p_data_id    number,
                              p_user_id    number,
                              p_invoice_id number,
                              x_status     out varchar2,
                              x_mess       out varchar2,
                              x_detail     out varchar2) is
    l_transaction_id number;
    l_linenum        number := 1;
    l_taxType        varchar2(20) := 'IN';
    l_transType      varchar2(20) := '20';
    l_transDate      date;
    l_modeluId       varchar2(20) := 'AP';
    ----
    --l_return_status varchar2(4000);
    --l_return_mess   varchar2(4000);
    --l_return_detail varchar2(4000);
  begin
  
    for tax in (select transNum,
                       transSymbol,
                       transDate,
                       itemName,
                       objectName,
                       objectTaxCode,
                       amtCcy,
                       amtTax,
                       amtLcy
                  FROM dev.dev_cpm_api_data j,
                       JSON_TABLE(j.json_data,
                                  '$.Invoice'
                                  COLUMNS(NESTED PATH '$.Tax[*]'
                                          COLUMNS(transNum varchar2(200) PATH
                                                  '$.transNum',
                                                  transSymbol varchar2(200) path
                                                  '$.transSymbol',
                                                  transDate varchar2(200) path
                                                  '$.transDate',
                                                  itemName varchar2(500) path
                                                  '$.itemName',
                                                  objectName VARCHAR2(500) PATH
                                                  '$.objectName',
                                                  objectTaxCode VARCHAR2(500) PATH
                                                  '$.objectTaxCode',
                                                  amtCcy NUMBER path
                                                  '$.amtCcy',
                                                  amtTax number path
                                                  '$.amtTax',
                                                  amtLcy number PATH
                                                  '$.amtLcy'))) t
                 WHERE j.data_id = p_data_id) loop
    
      l_transDate := to_date(tax.transdate, 'DD-MM-RRRR');
    
      select mc_vat_transactions_s.nextval into l_transaction_id from dual;
      insert into mc_vat_transactions
        (transaction_id,
         header_id,
         line_num,
         tax_type,
         trans_type,
         trans_symbol,
         trans_number,
         transation_date,
         item_name,
         object_name,
         object_tax_code,
         amt_ccy,
         amt_tax,
         amt_lcy,
         module_id,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login)
      values
        (l_transaction_id,
         p_invoice_id,
         l_linenum,
         l_taxType,
         l_transType,
         tax.transsymbol,
         tax.transnum,
         l_transDate,
         tax.itemname,
         tax.objectname,
         tax.objecttaxcode,
         tax.amtccy,
         tax.amttax,
         tax.amtlcy,
         l_modeluId,
         sysdate,
         p_user_id,
         sysdate,
         p_user_id,
         0);
      commit;
    end loop;
  end;
  -------------------------------------------------
  PROCEDURE sync_invoice(p_data_id    NUMBER,
                         --out
                         x_status OUT VARCHAR2,
                         x_mess   OUT VARCHAR2,
                         x_detail OUT VARCHAR2) IS
  l_invalid_json   number;
    l_return_status  varchar2(4000);
    l_return_mess    varchar2(4000);
    l_return_detail  varchar2(4000);
    l_payment_number varchar2(200);
    l_username       varchar2(400);
    l_user_id        number;
    l_invoice_id     number;
    l_invoice_num    varchar2(400);
    l_org_id         number;
    l_batch_id       number;
    v_Entity_Id      number;
    l_document       varchar2(200);
    l_isApply        varchar2(10);
    l_isPayment      varchar2(10);
    l_giftInvoice    varchar2(10);
    l_Exception      Exception;
  BEGIN
    x_status := 'S';
    SELECT dev_cpm_api_pkg.is_valid_json(j.json_data)
      INTO l_invalid_json
      FROM dev.DEV_CPM_API_DATA j
     WHERE j.data_id = p_data_id;
  
    IF l_invalid_json = 0 THEN
      l_return_status := 'E22STAV001';
      l_return_mess   := 'Dữ liệu tích hợp sai cấu trúc json!';
      l_return_detail := 'Dữ liệu tích hợp sai cấu trúc json!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise l_Exception;
    end if;
    BEGIN
      SELECT t.createBy
        INTO l_username
        FROM dev.dev_CPM_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Invoice'
                        COLUMNS(createBy varchar2(200) path '$.createBy')) t
       WHERE j.data_id = p_data_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_username := null;
    END;
    if l_username is null then
      l_return_status := 'E22PREV002';
      l_return_mess   := 'Người tạo chứng từ không được để trống!';
      l_return_detail := 'Người tạo chứng từ tối đa 100 ký tự!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise l_Exception;
    else
      begin
        select fu.USER_ID
          into l_user_id
          from fnd_user fu
         where upper(SUBSTR(fu.EMAIL_ADDRESS,
                            1,
                            INSTR(fu.EMAIL_ADDRESS, '@') - 1)) =
               upper(l_username)
           AND nvl(trunc(fu.END_DATE), SYSDATE + 1) >= trunc(SYSDATE);
      exception
        when others then
          l_user_id := null;
      end;
      if l_user_id is null then
        l_return_status := 'E22PREB003';
        l_return_mess   := 'Người tạo chưa được khai báo hoặc đã hết hiệu lực tại Oracle GL!';
        l_return_detail := 'Người tạo chưa được khai báo hoặc đã hết hiệu lực tại Oracle GL!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise l_Exception;
      end if;
    end if;
    check_invoice(p_data_id,
                   l_return_status,
                   l_return_mess,
                   l_return_detail);
    if l_return_status <> 'S' then
      x_status := l_return_status;
      x_mess   := l_return_mess;
      x_detail := l_return_detail;
      raise l_Exception;
    end if;
    create_invoice_header(p_data_id     => p_data_id,
                          p_user_id     => l_user_id,
                          x_invoice_id  => l_invoice_id,
                          x_invoice_num => l_invoice_num,
                          x_org_id      => l_org_id,
                          x_batch_id    => l_batch_id,
                          x_status      => l_return_status,
                          x_mess        => l_return_mess,
                          x_detail      => l_return_detail);
  
    COMMIT;
    IF l_invoice_id IS NOT NULL THEN
    
      -- lấy dữ liệu invoice line từ json
      BEGIN
        create_invoice_line(p_data_id    => p_data_id,
                            p_user_id    => l_user_id,
                            p_invoice_id => l_invoice_id,
                            --
                            x_status => l_return_status,
                            x_mess   => l_return_mess,
                            x_detail => l_return_detail);
      
      END;
      validate_invoice(p_data_id       => p_data_id,
                       p_user_id       => l_user_id,
                       p_org_id        => l_org_id,
                       p_invoice_id    => l_invoice_id,
                       x_return_status => l_return_status,
                       x_return_mess   => l_return_mess,
                       x_return_detail => l_return_detail);
      if l_return_status <> 'S' then
        x_status := l_return_status;
        x_mess   := l_return_mess;
        x_detail := l_return_detail;
        raise l_Exception;
      end if;
    END IF;
  
    SELECT Xte.Entity_Id
      INTO v_Entity_Id
      FROM Xla.Xla_Transaction_Entities Xte
     WHERE 1 = 1
       AND Xte.Entity_Code = 'AP_INVOICES'
       AND Xte.Source_Id_Int_1 = l_invoice_id
       AND Xte.Application_Id = 200;
    Create_Account(p_Application_Id  => 200,
                   p_Entity_Id       => v_entity_id,
                   p_Accounting_Mode => 'D',
                   x_Return_Status   => l_return_status,
                   x_Return_Mess     => l_return_mess);
    
    if l_return_status <> 'S' then
      x_status := l_return_status;
      x_mess   := l_return_mess;
      x_detail := l_return_detail;
      raise l_Exception;
    end if;
  
    create_tax_manual(p_data_id,
                      l_user_id,
                      l_invoice_id,
                      l_return_status,
                      l_return_mess,
                      l_return_detail);
  END;
end dev_cpm_invoice_pkg;
/
