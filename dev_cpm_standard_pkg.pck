﻿create or replace package dev_cpm_standard_pkg is
PROCEDURE Prc_Gen_Org(x_org_id          out number,
                        x_Org_Code        OUT VARCHAR2,
                        x_sob_id          out number,
                        x_Legal_Entity_Id OUT NUMBER);
  FUNCTION get_next_invoice_number(p_org_id IN NUMBER) RETURN VARCHAR2;
  procedure check_standard(p_data_id number,
                           p_user_id number,
                           x_status  OUT VARCHAR2,
                           x_mess    OUT VARCHAR2,
                           x_detail  out varchar2);
  PROCEDURE validate_invoice(p_user_id       number,
                             p_org_id        NUMBER,
                             p_invoice_id    IN NUMBER,
                             x_return_status OUT VARCHAR2,
                             x_return_mess   OUT VARCHAR2,
                             x_return_detail out varchar2);
  procedure create_payment(p_data_id    number,
                           p_invoice_id number,
                           p_org_id     number,
                           p_user_id    number,
                           --out
                           x_payment_number out varchar2,
                           x_status         out varchar2,
                           x_mess           out varchar2,
                           x_detail         out varchar2);
  procedure apply_prepayment(p_data_id    number,
                             p_invoice_id number,
                             p_user_id    number,
                             x_status     out varchar2,
                             x_mess       out varchar2,
                             x_detail     out varchar2);
  procedure import_journal(p_data_id    number,
                           p_invoice_id number,
                           p_org_id     number,
                           p_user_Id    number,
                           x_document   out varchar2,
                           x_status     out varchar2,
                           x_mess       out varchar2,
                           x_detail     out varchar2);
  PROCEDURE sync_standard(p_data_id NUMBER,
                          --out
                          x_status OUT VARCHAR2,
                          x_mess   OUT VARCHAR2,
                          x_detail OUT VARCHAR2);

end dev_cpm_standard_pkg;
/
create or replace package body dev_cpm_standard_pkg is
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
  ---------------
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
  -------------------
  procedure check_standard(p_data_id number,
                           p_user_id number,
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
  v_giftInvoice varchar2(10);
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
  v_remain_amount number;
    l_coa_id NUMBER;
    --l_username       varchar2(200);
    l_segment1      varchar2(20);
    l_segment2      varchar2(20);
    l_segment3      varchar2(20);
    l_segment4      varchar2(20);
    l_check_segment number;
    v_segment1      varchar2(20);
    v_segment2      varchar2(20);
    v_segment3      varchar2(20);
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
    v_applied_amount number;
    v_pre_amount number;
    v_pre_invoice number;
    v_pre_currency varchar2(200);
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
      select isApply, isPayment
        into l_isApply, v_isPayment
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$'
                        COLUMNS(isApply varchar2(1) path '$.Invoice.isApply',
                                isPayment varchar2(1) path '$.isPayment')) t
       where j.data_id = p_data_id;
    exception
      when others then
        l_isApply := null;
    end;
  
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
        l_segment1  := null;
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
      l_return_status := 'E22STAV001';
      l_return_mess   := 'Lỗi tại nhà cung cấp!';
      l_return_detail := 'Nhà cung cấp chưa có trên hệ thống Oracle GL. Kiểm tra lại mã số nhà cung cấp tại CPM hoặc thêm mới nhà cung cấp này!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      if l_Type = 'VENDOR' then
      begin
        select site.VENDOR_SITE_ID,
               site.ACCTS_PAY_CODE_COMBINATION_ID,
               site.PARTY_SITE_ID
          into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
          from ap_supplier_sites_all site
         where site.VENDOR_ID = l_vendor_id
           and (upper(site.VENDOR_SITE_CODE) like 'C%' or site.PAY_SITE_FLAG = 'Y')
           and rownum = 1;
      exception
        when others then
          --l_VENDOR_SITE_ID := NULL;
          v_liablity_cc_id := NULL;
          --l_party_site_id  := NULL;
      end;
    else
       begin
        select site.VENDOR_SITE_ID,
               site.ACCTS_PAY_CODE_COMBINATION_ID,
               site.PARTY_SITE_ID
          into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
          from ap_supplier_sites_all site
         where site.VENDOR_ID = l_vendor_id
           and (upper(site.VENDOR_SITE_CODE) like 'H%' or site.PAY_SITE_FLAG = 'Y')
           and rownum = 1;
      exception
        when others then
          --l_VENDOR_SITE_ID := NULL;
          v_liablity_cc_id := NULL;
          --l_party_site_id  := NULL;
      end;
      end if;
    END IF;
    if l_isApply is null then
      l_return_status := 'E22STAV002';
      l_return_mess   := 'Lỗi tại Trạng thái Apply của chứng từ!';
      l_return_detail := 'Trạng thái Apply bắt buộc phải có dữ liệu Y/N. Vui lòng kiểm tra lại tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      if l_isApply = 'Y' then
        select sum(applyAmount)
          into l_applyAmount
          from dev.dev_cpm_api_data j,
               JSON_TABLE(j.json_data,
                          '$.Invoice'
                          COLUMNS(NESTED PATH '$.ApplicationPrepayment[*]'
                                  COLUMNS(applyAmount number path
                                          '$.applyAmount'))) t
         where j.data_id = p_data_id;
        if nvl(l_invoiceAmount, 0) < nvl(l_applyAmount, 0) then
          l_return_status := 'E22STAB003';
          l_return_mess   := 'Lỗi tại Số tiền Apply!';
          l_return_detail := 'Số tiền Apply không được lớn hơn số tiền hóa đơn!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        end if;
        for pre in (select applyDate, applyPaymentNum, applyAmount
                      from dev.dev_cpm_api_data j,
                           JSON_TABLE(j.json_data,
                                      '$.Invoice'
                                      COLUMNS(NESTED PATH
                                              '$.ApplicationPrepayment[*]'
                                              COLUMNS(applyDate varchar2 path
                                                      '$.applyDate',
                                                      applyPaymentNum
                                                      varchar2(200) path
                                                      '$.applyPaymentNum', applyAmount number path '$.applyAmount'))) t
                     where j.data_id = p_data_id) loop
          if pre.applydate is null or
             dev_cpm_api_pkg.is_date(pre.applydate) = 'N' then
            l_return_status := 'E22STAV004';
            l_return_mess   := 'Lỗi tại Ngày Apply!';
            l_return_detail := 'Ngày apply không được để trống và phải đúng định dạng DD-MM-YYYY! Kiểm tra lại dữ liệu đã nhập tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
          select count(*)
            into l_check_preNum
            from ap_invoices_all ai
           where ai.ATTRIBUTE10 = pre.applypaymentnum;
          if l_check_preNum = 0 then
            l_return_status := 'E22STAB005';
            l_return_mess   := 'Lỗi tại Số hóa đơn Apply!';
            l_return_detail := 'Số hóa đơn Apply không được để trống hoặc không có trên hệ thống!Kiểm tra lại dữ liệu đã nhập tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          else
            select ai.INVOICE_AMOUNT, ai.INVOICE_ID, ai.INVOICE_CURRENCY_CODE
              into v_pre_amount, v_pre_invoice, v_pre_currency
              from ap_invoices_all ai
             where ai.ATTRIBUTE10 = pre.applypaymentnum;
            select -1*sum(ail.AMOUNT - nvl(ail.INCLUDED_TAX_AMOUNT, 0))
              into v_applied_amount
              from ap_invoice_lines_all ail
             where 1 = 1
               and ail.PREPAY_INVOICE_ID = v_pre_invoice;
               v_remain_amount := v_pre_amount - nvl(v_applied_amount,0);
               if l_invoiceCur <> v_pre_currency then
                 l_return_status := 'E22STAB056';
            l_return_mess   := 'Lỗi tại Loại tiền!';
            l_return_detail := 'Loại tiền tại các chứng từ cần apply không giống nhau! Kiểm tra lại tại CPM và Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
                 end if;
               if pre.applyAmount - v_remain_amount > 0 then
            l_return_status := 'E22STAB006';
            l_return_mess   := 'Lỗi tại Số tiền Apply!';
            l_return_detail := 'Số tiền Apply đã hết!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
                 end if;
          end if;
          begin
            select ai.VENDOR_ID
              into l_pre_vendor_id
              from ap_invoices_all ai
             where ai.ATTRIBUTE10 = pre.applypaymentnum;
          exception
            when others then
              l_pre_vendor_id := null;
          end;
          if l_pre_vendor_id <> l_vendor_id then
            l_return_status := 'E22STAB007';
            l_return_mess   := 'Lỗi tại Nhà cung cấp!';
            l_return_detail := 'Nhà cung cấp tại Invoice Prepayment không trùng với nhà cung cấp tại Invoice Standard! Kiểm tra lại dữ liệu đã nhập tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end loop;
      end if;
    end if;
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
      l_return_status := 'E22STAV008';
      l_return_mess   := 'Lỗi tại Ngày hạch toán!';
      l_return_detail := 'Ngày hạch toán bắt buộc định dạng DD-MM-RRRR! Kiểm tra lại dữ liệu đã nhập tại CPM!';
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
      l_return_status := 'E22STAB009';
      l_return_mess   := 'Lỗi tại Ngày hạch toán!';
      l_return_detail := 'Ngày hạch toán không thuộc kỳ GL! Kiểm tra lại ngày hạch toán tại CPM hoặc mở kỳ hạch toán tại GL!';
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
      l_return_status := 'E22STAB010';
      l_return_mess   := 'Lỗi tại Ngày hạch toán!';
      l_return_detail := 'Ngày hạch toán không thuộc kỳ AP! Kiểm tra lại ngày hạch toán tại CPM hoặc mở kỳ hạch toán tại AP!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    if l_type is null or l_type <> 'STANDARD' then
      l_return_status := 'E22STAB011';
      l_return_mess   := 'Lỗi tại Phân loại chứng từ!';
      l_return_detail := 'Phân loại chứng từ bắt buộc là Standard! Kiểm tra lại Phân loại chứng từ tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    end if;
    IF l_description IS NULL or lengthb(l_description) > 240 THEN
      l_return_status := 'E22STAV012';
      l_return_mess   := 'Lỗi tại Diễn giải!';
      l_return_detail := 'Diễn giải không được để trống và độ dài kỳ tự tối đa 240! Kiểm tra lại Diễn giải tại CPM!';
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
      l_return_status := 'E22STAB013';
      l_return_mess   := 'Lỗi tại Loại tiền!';
      l_return_detail := 'Loại tiền không được để trống hoặc không có trên hệ thống Oracle GL! Kiểm tra Loại tiền tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
      else
      if l_invoiceCur <> 'VND' then
      if l_exRate is null then
       
       l_return_status := 'E22STAB055';
      l_return_mess   := 'Lỗi tại Tỷ giá!';
      l_return_detail := 'Tỷ giá không được để trống! Bắt buộc nhập tỷ giá khi loại tiền khác VND tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail; 
    END IF;
    end if;
    END IF;
    IF l_invoiceAmount IS NULL THEN
      l_return_status := 'E22STAB014';
      l_return_mess   := 'Lỗi tại Số tiền hóa đơn!';
      l_return_detail := 'Số tiền hóa đơn không được để trống và phải có định dạng số! Kiểm tra Số tiền hóa đơn tại CPM!';
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
      l_return_status := 'E22STAV015';
      l_return_mess   := 'Lỗi tại Thời hạn thanh toán!';
      l_return_detail := 'Thời hạn thanh toán không đúng hoặc chưa được khai bảo trên Oracle GL! Kiểm tra Thời hạn thanh toán tại CPM!';
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
      l_return_status := 'E22STAV016';
      l_return_mess   := 'Lỗi tại Số tiền hạch toán bên Nợ (invoice line)!';
      l_return_detail := 'Số tiền hạch toán bên Nợ phải là định dạng số! Kiểm tra lại số tiền hạch toán tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    IF nvl(l_sum_line_amount, -1) <> nvl(l_invoice_amount, 0) THEN
      l_return_status := 'E22STAB017';
      l_return_mess   := 'Lỗi tại Tổng tiền!';
      l_return_detail := 'Tổng tiền hạch toán bên Nợ phải bằng tổng tiền bên Có! Kiểm tra lại số tiền hạch toán tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    END IF;
    if l_invoiceDFF is null or lengthb(l_invoiceDFF) > 240 then
      l_return_status := 'E22STAV018';
      l_return_mess   := 'Lỗi tại Thông tin bổ sung!';
      l_return_detail := 'Thông tin bổ sung không được để trống và có độ dài tối đa 240 ký tự! Kiểm tra Diễn giải tại CPM!';
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
      l_return_status := 'E22STAS019';
      l_return_mess   := 'Lỗi tại Số chứng từ tham chiếu CPM!';
      l_return_detail := 'Số chứng từ tham chiếu không được để trống! Liên hệ kỹ thuật hệ thống CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      if l_checkDocNumCpm <> 0 then
        l_return_status := 'E22STAB020';
        l_return_mess   := 'Lỗi tại Số chứng từ tham chiếu CPM!';
        l_return_detail := 'Số chứng từ tham chiếu đã tồn tại trên hệ thống Oracle GL! Chứng từ với số tham chiếu này đã được tạo thành công trên Oracle GL!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise I_Exception;
      end if;
    end if;
    if v_isPayment is null then
      l_return_status := 'E22STAV021';
      l_return_mess   := 'Lỗi Trạng thái thanh toán!';
      l_return_detail := 'Trạng thái thanh toán không được để trống! Phải có giá trị Y/N! Kiểm tra tại CPM!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise I_Exception;
    else
      if v_isPayment = 'Y' then
        begin
          SELECT payDate, payAmount, bankAccNum, payDescription
            into v_payDate,
                 v_payAmount,
                 v_bank_account_num,
                 v_payDescription
            FROM dev.dev_CPM_api_data j,
                 JSON_TABLE(j.json_data,
                            '$.Payment'
                            COLUMNS(payDate VARCHAR2(500) PATH '$.payDate',
                                    payAmount varchar2(200) path
                                    '$.payAmount',
                                    bankAccNum VARCHAR2(500) PATH
                                    '$.bankAccNum',
                                    payDescription varchar(500) path
                                    '$.payDescription')) t
           WHERE j.data_id = p_data_id;
        exception
          when others then
            v_payDate := null;
            --v_payAmount        := null;
            v_bank_account_num := null;
            --v_payDescription   := null;
        end;
      
        if v_payDate is null or dev_cpm_api_pkg.is_date(v_payDate) = 'N' then
          l_return_status := 'E22STAV022';
          l_return_mess   := 'Lỗi tại Ngày đến hạn!';
          l_return_detail := 'Ngày đến hạn không được để trống và bắt buộc định dạng DD-MM-RRRR! Vui lòng kiểm tra lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        
        end if;
        if v_bank_account_num is null then
          l_return_status := 'E22STAV023';
          l_return_mess   := 'Lỗi tại Tài khoản ngân hàng!';
          l_return_detail := 'Tài khoản Ngân hàng chi tiền không được để trống! Vui lòng kiểm tra lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          begin
            select cba.BANK_ACCOUNT_ID, cba.BANK_ACCOUNT_NAME
              into v_bank_account_id, v_bank_account_name
              from ce_bank_accounts cba
             where cba.BANK_ACCOUNT_NUM = v_bank_account_num;
          exception
            when others then
              v_bank_account_id := null;
              --v_bank_account_name := null;
          end;
          if v_bank_account_id is null then
            l_return_status := 'E22STAB024';
            l_return_mess   := 'Lỗi tại Tài khoản ngân hàng!';
            l_return_detail := 'Tài khoản ngân hàng chi tiền không được để trống! Vui lòng kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          else
            begin
              select v.BANK_ACCT_USE_ID
                into v_bank_acct_use_id
                from ce_bank_acct_uses_all v
               where v.BANK_ACCOUNT_ID = v_bank_account_id
                 and v.ORG_ID = l_org_id;
            exception
              when others then
                v_bank_acct_use_id := null;
            end;
            if v_bank_acct_use_id is null then
              l_return_status := 'E22STAV025';
              l_return_mess   := 'Lỗi tại Tài khoản ngân hàng!';
              l_return_detail := 'Không tìm thấy Tài khoản ngân hàng tương ứng' ||
                                 v_bank_account_id || ' ở OU ' || l_org_id ||
                                 'tại Oracle GL! Vui lòng kiểm tra lại tại CPM';
              x_status        := l_return_status;
              x_mess          := l_return_mess;
              x_detail        := l_return_detail;
              raise I_Exception;
            end if;
            begin
              select seq.DOC_SEQUENCE_ID, seq.DB_SEQUENCE_NAME, seq.NAME
                into v_doc_sequence_id,
                     v_db_document_seq_name,
                     v_sequence_name
                from Fnd_Document_Sequences       seq,
                     fnd_doc_sequence_assignments asgn
               where 1 = 1
                 and asgn.DOC_SEQUENCE_ID = seq.DOC_SEQUENCE_ID
                 and asgn.SET_OF_BOOKS_ID = l_sob_id
                 and asgn.CATEGORY_CODE = 'CHECK PAY';
            exception
              when others then
                v_doc_sequence_id := null;
            end;
            if v_doc_sequence_id is null then
              l_return_status := 'E22STAS026';
              l_return_mess   := 'Lỗi hệ thống ' || v_sequence_name;
              l_return_detail := 'Không tồn tại sequence ' ||
                                 v_sequence_name ||
                                 ' Vui lòng Liên hệ kỹ thuật hệ thống Oracle GL!';
              x_status        := l_return_status;
              x_mess          := l_return_mess;
              x_detail        := l_return_detail;
              raise I_Exception;
            end if;
            begin
              select prof.payment_profile_id, d.PAYMENT_DOCUMENT_ID
                into v_payment_profile_id, v_payment_document_id
                from ce_payment_documents d, iby_payment_profiles prof
               where prof.payment_format_code = d.FORMAT_CODE
                 and prof.system_profile_name = 'MC_Payment'
                 and d.INTERNAL_BANK_ACCOUNT_ID = v_bank_account_id
                 and d.INACTIVE_DATE is null
                 and rownum = 1;
            exception
              when others then
                v_payment_profile_id  := null;
                v_payment_document_id := null;
            end;
            if v_payment_profile_id is null or
               v_payment_document_id is null then
              l_return_status := 'E22STAS027';
              l_return_mess   := 'Lỗi hệ thống';
              l_return_detail := 'Không tồn tại payment_profile_id hoặc payment_document_id! Vui lòng Liên hệ kỹ thuật hệ thống Oracle GL!';
              x_status        := l_return_status;
              x_mess          := l_return_mess;
              x_detail        := l_return_detail;
              raise I_Exception;
            end if;
          end if;
        end if;
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
                      rec.segment5 || '.' || rec.segment4 || '.' ||
                      rec.segment6 || '.' || rec.segment7 || '.' ||
                      rec.segment8 || '.' || rec.segment9 || '.' ||
                      rec.segment10;
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
        l_return_status := 'E22STAV028';
        l_return_mess   := 'Lỗi tại Ngày hóa đơn!';
        l_return_detail := 'Ngày hóa đơn bắt buộc định dạng DD-MM-YYYY!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise I_Exception;
      
      end if;
    end loop;
    select giftInvoice
    into v_giftInvoice
    FROM dev.dev_cpm_api_data j,
                           JSON_TABLE(j.json_data,
                                      '$' COLUMNS(giftInvoice VARCHAR2(500) PATH
                                              '$.giftInvoice')) t
     where j.data_id = p_data_id;
     if v_giftInvoice = 'Y' then
    for journal in (select 
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
                           segment11,
                           amountDr,
                           amountCr,
                           budget,
                           campaign,
                           fromDate,
                           toDate,
                           app,
                           partner,
                           customer,
                           employee
                      FROM dev.dev_cpm_api_data j,
                           JSON_TABLE(j.json_data,
                                      '$.Journal' COLUMNS(NESTED PATH '$.LineJournal[*]'
                                      columns(
                                              segment1 varchar2(30) path
                                              '$.segment1',
                                              segment2 VARCHAR2(200) PATH
                                              '$.segment2',
                                              segment3 varchar2(200) PATH
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
                                              amountDr varchar2(200) path
                                              '$.amountDr',
                                              amountCr varchar2(200) path
                                              '$.amountCr',
                                              budget varchar2(200) path
                                              '$.budget',
                                              campaign VARCHAR2(500) PATH
                                              '$.campaign',
                                              fromDate VARCHAR2(500) PATH
                                              '$.fromDate',
                                              toDate VARCHAR2(500) PATH
                                              '$.toDate',
                                              app VARCHAR2(500) PATH
                                              '$.app',
                                              partner varchar2(200) path
                                              '$.partner',
                                              customer varchar2(200) path
                                              '$.customer',
                                              employee varchar2(200) path
                                              '$.employee'))) t
                     WHERE j.data_id = p_data_id) loop
    
        if journal.segment1 is null then
          l_return_status := 'E22STAB029';
          l_return_mess   := 'Lỗi tại Chi nhánh!';
          l_return_detail := 'Chi nhánh không được để trống, bắt buộc nhập tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
        
          select count(*)
            into l_check_segment
            from fnd_flex_value_sets fvs, fnd_flex_values ffv
           where fvs.FLEX_VALUE_SET_NAME = 'MF_COA_BRANCH'
             and fvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
             and ffv.FLEX_VALUE = journal.segment1;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV030';
            l_return_mess   := 'Lỗi tại Chi nhánh!';
            l_return_detail := 'Chi nhánh không tồn tại trên Oracle GL! Vui lòng kiểm tra lại dữ liệu COA Branch tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          
          end if;
        end if;
        if journal.segment2 is null then
          l_return_status := 'E22STAB031';
          l_return_mess   := 'Lỗi tại Khối!';
          l_return_detail := 'Khối không được để trống, bắt buộc nhập tại CPM!';
        
          x_status := l_return_status;
          x_mess   := l_return_mess;
          x_detail := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_value_sets fvs, fnd_flex_values ffv
           where fvs.FLEX_VALUE_SET_NAME = 'MF_COA_DIVISION'
             and fvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
             and ffv.FLEX_VALUE = journal.segment2
             and ffv.PARENT_FLEX_VALUE_LOW = journal.segment1;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV032';
            l_return_mess   := 'Lỗi tại Khối!';
            l_return_detail := 'Khối không tồn tại trên Oracle GL! Vui lòng kiểm tra lại dữ liệu COA Division tại CPM!';
          
            x_status := l_return_status;
            x_mess   := l_return_mess;
            x_detail := l_return_detail;
            raise I_Exception;
          end if;
        
        end if;
        if journal.segment3 is null then
          l_return_status := 'E22STAB033';
          l_return_mess   := 'Lỗi tại phòng ban!';
          l_return_detail := 'Phòng ban không được để trống, bắt buộc nhập tại CPM!';
        
          x_status := l_return_status;
          x_mess   := l_return_mess;
          x_detail := l_return_detail;
          raise I_Exception;
        else
        
          select count(*)
            into l_check_segment
            from MF_COA_DEPARTMENT_V t
           where t.attribute1 = journal.segment2
             and t.parent_flex_value_low = journal.segment1
             and t.flex_value = journal.segment3;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV034';
            l_return_mess   := 'Lỗi tại Phòng ban!';
            l_return_detail := 'Mã phòng ban không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment11 is null then
          l_return_status := 'E22STAB035';
          l_return_mess   := 'Lỗi tại Bộ phận!';
          l_return_detail := 'Mã bộ phận không được để trống, bắt buộc nhập tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from MF_COA_UNIT_V a
           where nvl(a.attribute1, 'x') =
                 decode(a.attribute1, null, 'x', journal.segment2)
             and a.attribute3 = journal.segment3
             and a.parent_flex_value_low = journal.segment1
             and a.summary_flag = 'N'
             and a.enabled_flag = 'Y'
             and nvl(a.start_date_active, trunc(sysdate)) between
                 trunc(sysdate) and nvl(a.end_date_active, trunc(sysdate))
             and a.flex_value = journal.segment11;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV036';
            l_return_mess   := 'Lỗi tại Bộ phận!';
            l_return_detail := 'Bộ phận không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment4 is null then
          l_return_status := 'E22STAB037';
          l_return_mess   := 'Lỗi tại Tài khoản!';
          l_return_detail := 'Tài khoản không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_COA_ACCOUNT'
             and flv.FLEX_VALUE = journal.segment4;
          if l_check_segment = 0 then
            l_return_status := 'E22STAB038';
            l_return_mess   := 'Lỗi tại Tài khoản!';
            l_return_detail := 'Mã Tài khoản không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment5 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Chức danh!';
          l_return_detail := 'Mã Chức danh không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_COA_POSITION'
             and flv.FLEX_VALUE = journal.segment5;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Chức danh!';
            l_return_detail := 'Mã Chức danh không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment6 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Sản phẩm!';
          l_return_detail := 'Mã Sản phẩm không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_COA_SUB_PRODUCT'
             and flv.FLEX_VALUE = journal.segment6;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Sản phẩm!';
            l_return_detail := 'Mã Sản phẩm không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment7 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Nhóm khách hàng!';
          l_return_detail := 'Mã Nhóm khách hàng không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from MF_COA_CUSTOMER_CLASS_V flv
             where flv.FLEX_VALUE = journal.segment7;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Nhóm khách hàng!';
            l_return_detail := 'Mã Nhóm khách hàng không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment8 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Kênh bán hàng!';
          l_return_detail := 'Mã Kênh bán hàng không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from MF_COA_CHANNEL_CLASS_V flv
             where flv.FLEX_VALUE = journal.segment8;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Kênh bán hàng!';
            l_return_detail := 'Mã Kênh bán hàng không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment9 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Pos/Kiosk/Hub..!';
          l_return_detail := 'Mã Pos/Kiosk/Hub.. không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_COA_SUB_CHANNEL'
             and flv.FLEX_VALUE = journal.segment9;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Pos/Kiosk/Hub..!';
            l_return_detail := 'Mã Pos/Kiosk/Hub.. không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.segment10 is null then
          l_return_status := 'E22STAB039';
          l_return_mess   := 'Lỗi tại Loại dữ liệu!';
          l_return_detail := 'Mã Loại dữ liệu không được để trống! Bắt buộc nhập lại tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        else
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_COA_RESERVE'
             and flv.FLEX_VALUE = journal.segment10;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV040';
            l_return_mess   := 'Lỗi tại Loại dữ liệu!';
            l_return_detail := 'Mã Loại dữ liệu không tồn tại trên Oracle GL! Kiểm tra lại tại CPM!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        l_concat_seg := journal.segment1 || '.' || journal.segment2 || '.' ||
                        journal.segment3 || '.' || journal.segment11 || '.' ||
                        journal.segment5 || '.' || journal.segment4 || '.' ||
                        journal.segment6 || '.' || journal.segment7 || '.' ||
                        journal.segment8 || '.' || journal.segment9 || '.' ||
                        journal.segment10;
        dev_cpm_api_pkg.check_ccid(p_coa_id     => l_coa_id,
                                   p_concat_seg => l_concat_seg,
                                   x_ccid       => v_liablity_cc_id,
                                   x_status     => l_return_status,
                                   x_mess       => l_return_mess,
                                   x_detail     => l_return_detail);
        if l_return_status <> 'S' then
          x_status := l_return_status;
          x_mess   := l_return_mess;
          x_detail := l_return_detail;
          raise I_Exception;
        end if;
        
        if journal.amountDr is not null and
           dev_cpm_api_pkg.is_number(journal.amountDr) = 'N' then
          l_return_status := 'E22STAB041';
          l_return_mess   := 'Lỗi tại Số tiền hạch toán Nợ!';
          l_return_detail := 'Số tiền hạch toán Nợ phải có định dạng số! Bắt buộc nhập dữ liệu dạng số tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        end if;
        if journal.amountCr is not null and
           dev_cpm_api_pkg.is_number(journal.amountCr) = 'N' then
          l_return_status := 'E22STAB041';
          l_return_mess   := 'Lỗi tại Số tiền hạch toán Có!';
          l_return_detail := 'Số tiền hạch toán Có phải có định dạng số! Bắt buộc nhập dữ liệu dạng số tại CPM!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        end if;
        if journal.amountdr is not null and journal.amountcr is not null then
          l_return_status := 'E22STAB041';
          l_return_mess   := 'Lỗi tại Số tiền hạch toán!';
          l_return_detail := 'Số tiền hạch toán chỉ được nhập 1 vế Nợ/Có';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
          end if;
        if journal.budget is not null then
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_BUDGET'
             and flv.FLEX_VALUE = journal.budget;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV042';
            l_return_mess   := 'Lỗi tại Mã Ngân sách!';
            l_return_detail := 'Mã Ngân sách không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.campaign is not null then
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_Campaign'
             and flv.FLEX_VALUE = journal.campaign;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV043';
            l_return_mess   := 'Lỗi tại Mã chiến dịch!';
            l_return_detail := 'Mã chiến dịch không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.fromdate is not null and
           dev_cpm_api_pkg.is_date(journal.fromdate) = 'N' then
          l_return_status := 'E22STAB044';
          l_return_mess   := 'Lỗi tại Từ ngày phát sinh chi phí!';
          l_return_detail := 'Từ ngày phát sinh chi phí bắt buộc nhập tại CPM và phải có định dạng ngày DD-MM-YYYY!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        end if;
        if journal.todate is not null and
           dev_cpm_api_pkg.is_date(journal.todate) = 'N' then
          l_return_status := 'E22STAB045';
          l_return_mess   := 'Lỗi tại Đến Ngày phát sinh chi phí!';
          l_return_detail := 'Đến ngày phát sinh chi phí bắt buộc nhập tại CPM và phải có định dạng ngày DD-MM-YYYY!';
          x_status        := l_return_status;
          x_mess          := l_return_mess;
          x_detail        := l_return_detail;
          raise I_Exception;
        end if;
        if journal.app is not null then
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_Application'
             and flv.FLEX_VALUE = journal.app;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV046';
            l_return_mess   := 'Lỗi tại Mã ứng dụng!';
            l_return_detail := 'Mã ứng dụng không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.partner is not null then
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_PARTNER'
             and flv.FLEX_VALUE = journal.partner;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV047';
            l_return_mess   := 'Lỗi tại Mã đối tác hợp tác!';
            l_return_detail := 'Mã đối tác hợp tác không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.customer is not null then
          select count(*)
            into l_check_segment
            from fnd_flex_values flv, fnd_flex_value_sets ffs
           where flv.FLEX_VALUE_SET_ID = ffs.FLEX_VALUE_SET_ID
             and ffs.FLEX_VALUE_SET_NAME = 'MF_KHACHHANG'
             and flv.FLEX_VALUE = journal.customer;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV048';
            l_return_mess   := 'Lỗi tại Mã khách hàng!';
            l_return_detail := 'Mã khách hàng không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
        if journal.employee is not null then
          select count(*)
            into l_check_segment
            from MC_HR_EMPLOYEES_V flv
           where 1=1
             and flv.EMP_CODE = journal.employee;
          if l_check_segment = 0 then
            l_return_status := 'E22STAV049';
            l_return_mess   := 'Lỗi tại Mã nhân viên!';
            l_return_detail := 'Mã nhân viên không tồn tại trên Oracle GL!';
            x_status        := l_return_status;
            x_mess          := l_return_mess;
            x_detail        := l_return_detail;
            raise I_Exception;
          end if;
        end if;
    end loop;
    end if;
  exception
    when I_Exception then
      null;
  end;
  -------------------
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
    l_termDate      DATE;
    v_paymentAmount number;
    --v_termDate      VARCHAR2(200);
    l_invoiceDFF VARCHAR2(500);
  
    l_supplierSite         varchar2(200);
    v_invoiceDate          varchar2(200);
    v_doc_sequence_id      number;
    v_db_document_seq_name varchar2(200);
    v_sequence_name        varchar2(200);
    l_sql                  varchar2(2000);
    v_doc_sequence_num     number;
    v_doc_category_code    varchar2(200);
    l_exType               varchar2(200) := 'User';
    l_exRate               number;
    l_empCode              varchar2(200);
    l_empManager           varchar2(200);
    l_contract             varchar2(200);
    l_docNum               varchar2(200);
    l_project              varchar2(200);
    l_empType              varchar2(200);
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
    begin
      select payAmount
        into v_paymentAmount
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Payment'
                        COLUMNS(payAmount number path '$.payAmount')) t
       WHERE j.data_id = p_data_id;
    exception
      when others then
        v_paymentAmount := null;
    end;
    BEGIN
      SELECT at.TERM_ID
        INTO l_term_id
        FROM ap_terms at
       WHERE at.NAME = '1D';
    EXCEPTION
      WHEN OTHERS THEN
        l_term_id := NULL;
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
  if l_Type = 'VENDOR' then
    begin
      select site.VENDOR_SITE_ID,
             site.ACCTS_PAY_CODE_COMBINATION_ID,
             site.PARTY_SITE_ID
        into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
        from ap_supplier_sites_all site
       where site.VENDOR_ID = l_vendor_id
         and (upper(site.VENDOR_SITE_CODE) like 'C%' or site.PAY_SITE_FLAG = 'Y')
         and rownum =1;
    exception
      when others then
        l_VENDOR_SITE_ID := NULL;
        v_liablity_cc_id := NULL;
        l_party_site_id  := NULL;
    end;
    else
       begin
      select site.VENDOR_SITE_ID,
             site.ACCTS_PAY_CODE_COMBINATION_ID,
             site.PARTY_SITE_ID
        into l_VENDOR_SITE_ID, v_liablity_cc_id, l_party_site_id
        from ap_supplier_sites_all site
       where site.VENDOR_ID = l_vendor_id
         and (upper(site.VENDOR_SITE_CODE) like 'H%' or site.PAY_SITE_FLAG = 'Y')
         and rownum = 1;
    exception
      when others then
        l_VENDOR_SITE_ID := NULL;
        v_liablity_cc_id := NULL;
        l_party_site_id  := NULL;
    end;
      end if;
    l_glDate      := to_date(v_glDate, 'DD-MM-RRRR');
    v_invoice_num := get_next_invoice_number(l_org_id);
  
    begin
      select seq.DOC_SEQUENCE_ID, seq.DB_SEQUENCE_NAME, seq.NAME
        into v_doc_sequence_id, v_db_document_seq_name, v_sequence_name
        from fnd_document_sequences seq, fnd_doc_sequence_assignments asgn
       where 1 = 1
         and asgn.DOC_SEQUENCE_ID = seq.DOC_SEQUENCE_ID
         and asgn.SET_OF_BOOKS_ID = l_sob_id
         and asgn.CATEGORY_CODE = 'PREPAY INV';
    exception
      when others then
        v_doc_sequence_id := null;
      
    end;
    begin
      l_sql := 'Select ' || v_db_document_seq_name || '.nextval from dual';
      execute immediate l_sql
        into v_doc_sequence_num;
    end;
    begin
      select c.code
        into v_doc_category_code
        from fnd_doc_sequence_categories c
       where c.CODE = 'STD INV';
    end;
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
                                       p_Terms_Date                  => l_glDate,
                                       p_Goods_Received_Date         => NULL,
                                       p_Invoice_Received_Date       => NULL,
                                       p_Voucher_Num                 => NULL,
                                       p_Approved_Amount             => l_invoiceAmount,
                                       p_Approval_Status             => NULL,
                                       p_Approval_Description        => NULL,
                                       p_Pay_Group_Lookup_Code       => null,
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
                                       p_Doc_Sequence_Id             => v_doc_sequence_id,
                                       p_Doc_Sequence_Value          => v_doc_sequence_num,
                                       p_Doc_Category_Code           => v_doc_category_code,
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
  -------------------
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
    
      v_concat_seg := rec.segment1 || '.' || rec.segment2 || '.' ||
                      rec.segment3 || '.' || rec.segment11 || '.' ||
                      rec.segment5 || '.' || rec.segment4 || '.' ||
                      rec.segment6 || '.' || rec.segment7 || '.' ||
                      rec.segment8 || '.' || rec.segment9 || '.' ||
                      rec.segment10;
    
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
     -- COMMIT;
    
    END LOOP; -- dữ liệu line
  END;
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
      --commit;
    end loop;
  end;
  ------------------
  PROCEDURE validate_invoice(p_user_id       number,
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
      /* SELECT frv.responsibility_id
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
   -- COMMIT;
    dbms_output.put_line('lx_approval_status: ' || lx_approval_status);
    IF lx_approval_status IN ('APPROVED', 'AVAILABLE', 'UNPAID', 'FULL') THEN
      x_return_status := 'S';
      x_return_mess   := 'Validate invoice thành công!';
      x_return_detail := 'Validate invoice thành công!';
    ELSE
      x_return_status := 'E22STAS050';
      x_return_mess   := 'Lỗi validate invoice!';
      x_return_detail := 'Kiểm tra số chứng từ ' || l_invoice_number ||
                         ' tại Oracle GL!';
    
    END IF;
  END validate_invoice;
  --------------------
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
   -- COMMIT;
  END Create_Account;
  ------------------
  procedure create_payment(p_data_id    number,
                           p_invoice_id number,
                           p_org_id     number,
                           p_user_id    number,
                           --out
                           x_payment_number out varchar2,
                           x_status         out varchar2,
                           x_mess           out varchar2,
                           x_detail         out varchar2) is
    v_check_id             number;
    v_init_msg_list        varchar2(200);
    v_check_number         number;
    v_msg_count            number;
    v_msg_data             varchar2(300);
    v_resp_id              number := 50763;
    v_resp_appl_id         number := 200;
    v_party_id             number;
    v_party_site_id        number;
    v_payDate              varchar2(200);
    l_payDate              date;
    v_payamount            number;
    v_payDescription       varchar2(500);
    v_bank_account_num     varchar2(300);
    v_bank_account_name    varchar2(300);
    v_bank_account_id      number;
    v_bank_acct_use_id     number;
    v_doc_sequence_id      number;
    l_sql                  varchar2(4000);
    v_db_document_seq_name varchar2(4000);
    v_sequence_name        varchar2(4000);
    v_sob_id               number;
    v_doc_sequence_num     number;
    v_doc_category_code    varchar2(500);
    v_payment_profile_id   number;
    v_payment_document_id  number;
    v_checkrun_name        varchar2(400);
    v_status_lookup_code   varchar2(400);
    v_vendor_id            number;
    v_vendor_site_id       number;
    v_payment_method_code  varchar2(30);
    v_bank_charge_bearer   varchar2(1);
    v_payment_type_flag    varchar2(1);
    x_rowid_out            varchar2(200);
    v_base_amount          number;
    v_invoice_currency     varchar2(30);
    v_ex_rate              number;
    v_ex_rate_type         varchar2(200);
    v_ex_date              date;
    v_legal_entity_id      number;
    v_transaction_type     varchar2(200);
    v_glDate               date;
    v_accounting_event_id  number;
    v_payment_num          varchar2(200);
    v_invoice_payment_id   number;
    v_period_name          varchar2(200);
    v_invoice_number       varchar2(200);
    v_account_liability_id number;
    v_amount               number;
    v_invoice_type         varchar2(200);
    --v_entity_id            number;
    --
    l_return_status varchar2(4000);
    l_return_mess   varchar2(4000);
    l_return_detail varchar2(4000);
    ---
    v_invalid Exception;
  begin
    x_status := 'S';
    Mo_Global.init('SQLAP');
  
    begin
      /* SELECT frv.responsibility_id
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
    fnd_global.APPS_INITIALIZE(user_id      => p_user_id,
                               resp_id      => v_resp_id,
                               resp_appl_id => v_resp_appl_id);
    Mo_Global.set_policy_context('S', p_org_id);
    select a.PARTY_ID,
           a.PARTY_SITE_ID,
           a.SET_OF_BOOKS_ID,
           a.VENDOR_ID,
           a.VENDOR_SITE_ID,
           a.INVOICE_CURRENCY_CODE,
           a.EXCHANGE_RATE_TYPE,
           a.EXCHANGE_RATE,
           a.EXCHANGE_DATE,
           a.GL_DATE
      into v_party_id,
           v_party_site_id,
           v_sob_id,
           v_vendor_id,
           v_vendor_site_id,
           v_invoice_currency,
           v_ex_rate_type,
           v_ex_rate,
           v_ex_date,
           v_glDate
      from ap_invoices_all a
     where a.INVOICE_ID = p_invoice_id;
  
    begin
      SELECT payDate, payAmount, bankAccNum, payDescription
        into v_payDate, v_payAmount, v_bank_account_num, v_payDescription
        FROM dev.dev_CPM_api_data j,
             JSON_TABLE(j.json_data,
                        '$.Payment'
                        COLUMNS(payDate VARCHAR2(500) PATH '$.payDate',
                                payAmount NUMBER path '$.payAmount',
                                bankAccNum VARCHAR2(500) PATH '$.bankAccNum',
                                payDescription varchar(500) path
                                '$.payDescription')) t
       WHERE j.data_id = p_data_id;
    exception
      when others then
        v_payDate          := null;
        v_payAmount        := null;
        v_bank_account_num := null;
        v_payDescription   := null;
    end;
    l_payDate := to_date(v_payDate, 'DD-MM-RRRR');
  
    begin
      select cba.BANK_ACCOUNT_ID, cba.BANK_ACCOUNT_NAME
        into v_bank_account_id, v_bank_account_name
        from ce_bank_accounts cba
       where cba.BANK_ACCOUNT_NUM = v_bank_account_num;
    exception
      when others then
        v_bank_account_id   := null;
        v_bank_account_name := null;
    end;
  
    begin
      select v.BANK_ACCT_USE_ID
        into v_bank_acct_use_id
        from ce_bank_acct_uses_all v
       where v.BANK_ACCOUNT_ID = v_bank_account_id
         and v.ORG_ID = p_org_id;
    exception
      when others then
        v_bank_acct_use_id := null;
    end;
  
    begin
      select seq.DOC_SEQUENCE_ID, seq.DB_SEQUENCE_NAME, seq.NAME
        into v_doc_sequence_id, v_db_document_seq_name, v_sequence_name
        from Fnd_Document_Sequences seq, fnd_doc_sequence_assignments asgn
       where 1 = 1
         and asgn.DOC_SEQUENCE_ID = seq.DOC_SEQUENCE_ID
         and asgn.SET_OF_BOOKS_ID = v_sob_id
         and asgn.CATEGORY_CODE = 'CHECK PAY';
    exception
      when others then
        v_doc_sequence_id := null;
    end;
    begin
      l_sql := 'select ' || v_db_document_seq_name || '.nextval from dual';
      execute immediate l_sql
        into v_doc_sequence_num;
    end;
    begin
      select c.code
        into v_doc_category_code
        from fnd_doc_sequence_categories c
       where c.code = 'CHECK PAY';
    exception
      when others then
        v_doc_category_code := null;
    end;
    begin
      select prof.payment_profile_id, d.PAYMENT_DOCUMENT_ID
        into v_payment_profile_id, v_payment_document_id
        from ce_payment_documents d, iby_payment_profiles prof
       where prof.payment_format_code = d.FORMAT_CODE
         and prof.system_profile_name = 'MC_Payment'
         and d.INTERNAL_BANK_ACCOUNT_ID = v_bank_account_id
         and d.INACTIVE_DATE is null
         and rownum = 1;
    exception
      when others then
        v_payment_profile_id  := null;
        v_payment_document_id := null;
    end;
  
    select ap_checks_s.nextval into v_check_id from dual;
    begin
      iby_disburse_ui_api_pub_pkg.validate_paper_doc_number(p_api_version       => 1.0,
                                                            p_init_msg_list     => v_init_msg_list,
                                                            p_payment_doc_id    => v_payment_document_id,
                                                            x_paper_doc_num     => v_check_number,
                                                            x_return_status     => l_return_status,
                                                            x_msg_count         => v_msg_count,
                                                            x_msg_data          => v_msg_data,
                                                            show_warn_msgs_flag => 'T');
    exception
      when others then
        l_return_status := 'E22STAB038';
        l_return_mess   := 'Lỗi hệ thống không validate được paper doc number';
        l_return_detail := 'Không validate được paper doc number';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise v_invalid;
      
    end;
   -- commit;
    v_checkrun_name       := 'Quick payment: ID=' || v_check_id;
    v_status_lookup_code  := 'NEGOTIABLE';
    v_payment_method_code := 'CHECK';
    v_bank_charge_bearer  := 'I';
    if v_payAmount < 0 then
      v_payment_type_flag := 'R';
    else
      v_payment_type_flag := 'Q';
    end if;
    if v_invoice_currency <> 'VND' then
      v_base_amount := v_payAmount * v_ex_rate;
    end if;
    dbms_output.put_line('check_id: ' || v_check_id);
    dbms_output.put_line('check_number: ' || v_check_number);
    dbms_output.put_line('v_doc_sequence_id: ' || v_doc_sequence_id);
    dbms_output.put_line('v_doc_sequence_num: ' || v_doc_sequence_num);
    dbms_output.put_line('v_doc_category_code: ' || v_doc_category_code);
    begin
      ap_checks_pkg.Insert_Row(X_Rowid                        => x_rowid_out,
                               X_Amount                       => v_payAmount,
                               X_Ce_Bank_Acct_Use_Id          => v_bank_acct_use_id,
                               X_Bank_Account_Name            => v_bank_account_name,
                               X_Check_Date                   => l_paydate,
                               X_Check_Id                     => v_check_id,
                               X_Check_Number                 => v_check_number,
                               X_Currency_Code                => v_invoice_currency,
                               X_Last_Updated_By              => p_user_id,
                               X_Last_Update_Date             => sysdate,
                               X_Payment_Type_Flag            => v_payment_type_flag,
                               X_Address_Line1                => null,
                               X_Address_Line2                => null,
                               X_Address_Line3                => null,
                               X_Checkrun_Name                => v_checkrun_name,
                               X_Check_Format_Id              => null,
                               X_Check_Stock_Id               => null,
                               X_City                         => null,
                               X_Country                      => null,
                               X_Created_By                   => p_user_id,
                               X_Creation_Date                => sysdate,
                               X_Last_Update_Login            => null,
                               X_Status_Lookup_Code           => v_status_lookup_code,
                               X_Vendor_Name                  => null,
                               X_Vendor_Site_Code             => null,
                               X_External_Bank_Account_Id     => null,
                               X_Zip                          => null,
                               X_Bank_Account_Num             => v_bank_account_num,
                               X_Bank_Account_Type            => null,
                               X_Bank_Num                     => null,
                               X_Check_Voucher_Num            => v_doc_sequence_num,
                               X_Cleared_Amount               => null,
                               X_Cleared_Date                 => null,
                               X_Doc_Category_Code            => v_doc_category_code,
                               X_Doc_Sequence_Id              => v_doc_sequence_id,
                               X_Doc_Sequence_Value           => v_doc_sequence_num,
                               X_Province                     => null,
                               X_Released_Date                => null,
                               X_Released_By                  => null,
                               X_State                        => null,
                               X_Stopped_Date                 => null,
                               X_Stopped_By                   => null,
                               X_Void_Date                    => null,
                               X_Attribute1                   => null,
                               X_Attribute10                  => null,
                               X_Attribute11                  => null,
                               X_Attribute12                  => null,
                               X_Attribute13                  => null,
                               X_Attribute14                  => null,
                               X_Attribute15                  => null,
                               X_Attribute2                   => null,
                               X_Attribute3                   => null,
                               X_Attribute4                   => null,
                               X_Attribute5                   => null,
                               X_Attribute6                   => null,
                               X_Attribute7                   => null,
                               X_Attribute8                   => null,
                               X_Attribute9                   => null,
                               X_Attribute_Category           => null,
                               X_Future_Pay_Due_Date          => null,
                               X_Treasury_Pay_Date            => null,
                               X_Treasury_Pay_Number          => null,
                               X_Withholding_Status_Lkup_Code => null,
                               X_Reconciliation_Batch_Id      => null,
                               X_Cleared_Base_Amount          => null,
                               X_Cleared_Exchange_Rate        => null,
                               X_Cleared_Exchange_Date        => null,
                               X_Cleared_Exchange_Rate_Type   => null,
                               X_Address_Line4                => null,
                               X_County                       => null,
                               X_Address_Style                => 'DEFAULT',
                               X_Org_Id                       => p_org_id,
                               X_Vendor_Id                    => v_vendor_id,
                               X_Vendor_Site_Id               => v_vendor_site_id,
                               X_Exchange_Rate                => v_ex_rate,
                               X_Exchange_Date                => v_ex_date,
                               X_Exchange_Rate_Type           => v_ex_rate_type,
                               X_Base_Amount                  => v_base_amount,
                               X_Checkrun_Id                  => null,
                               X_global_attribute_category    => null,
                               X_global_attribute1            => null,
                               X_global_attribute2            => null,
                               X_global_attribute3            => null,
                               X_global_attribute4            => null,
                               X_global_attribute5            => null,
                               X_global_attribute6            => null,
                               X_global_attribute7            => null,
                               X_global_attribute8            => null,
                               X_global_attribute9            => null,
                               X_global_attribute10           => null,
                               X_global_attribute11           => null,
                               X_global_attribute12           => null,
                               X_global_attribute13           => null,
                               X_global_attribute14           => null,
                               X_global_attribute15           => null,
                               X_global_attribute16           => null,
                               X_global_attribute17           => null,
                               X_global_attribute18           => null,
                               X_global_attribute19           => null,
                               X_global_attribute20           => null,
                               X_transfer_priority            => null,
                               X_maturity_exchange_rate_type  => null,
                               X_maturity_exchange_date       => null,
                               X_maturity_exchange_rate       => null,
                               X_description                  => v_payDescription,
                               X_anticipated_value_date       => null,
                               X_actual_value_date            => null,
                               x_payment_method_code          => v_payment_method_code,
                               x_payment_profile_id           => v_payment_profile_id,
                               x_bank_charge_bearer           => v_bank_charge_bearer,
                               x_settlement_priority          => null,
                               x_payment_document_id          => v_payment_document_id,
                               x_party_id                     => v_party_id,
                               x_party_site_id                => v_party_site_id,
                               x_legal_entity_id              => v_legal_entity_id,
                               x_payment_id                   => null,
                               X_calling_sequence             => 'APXPAWKB',
                               X_Remit_To_Supplier_Name       => null,
                               X_Remit_To_Supplier_Id         => null,
                               X_Remit_To_Supplier_Site       => null,
                               X_Remit_To_Supplier_Site_Id    => null,
                               X_Relationship_Id              => null,
                               X_paycard_authorization_number => null,
                               X_paycard_reference_id         => null);
     -- commit;
    exception
      when others then
        l_return_status := 'E22STAB039';
        l_return_mess   := 'Lỗi không tạo được payment';
        l_return_detail := 'Lỗi hệ thống! Không tạo được Payment. Vui lòng liên hệ IT! ' ||
                           sqlerrm;
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise v_invalid;
    end;
  
    if v_payamount < 0 then
      v_transaction_type := 'REFUND RECORDED';
    else
      v_transaction_type := 'PAYMENT CREATED';
    end if;
  
    begin
      ap_reconciliation_pkg.Insert_Payment_History(X_CHECK_ID                    => v_check_id,
                                                   X_TRANSACTION_TYPE            => v_transaction_type,
                                                   X_ACCOUNTING_DATE             => v_gldate,
                                                   X_TRX_BANK_AMOUNT             => null,
                                                   X_ERRORS_BANK_AMOUNT          => null,
                                                   X_CHARGES_BANK_AMOUNT         => null,
                                                   X_BANK_CURRENCY_CODE          => null,
                                                   X_BANK_TO_BASE_XRATE_TYPE     => null,
                                                   X_BANK_TO_BASE_XRATE_DATE     => null,
                                                   X_BANK_TO_BASE_XRATE          => null,
                                                   X_TRX_PMT_AMOUNT              => v_payamount,
                                                   X_ERRORS_PMT_AMOUNT           => null,
                                                   X_CHARGES_PMT_AMOUNT          => null,
                                                   X_PMT_CURRENCY_CODE           => v_invoice_currency,
                                                   X_PMT_TO_BASE_XRATE_TYPE      => null,
                                                   X_PMT_TO_BASE_XRATE_DATE      => null,
                                                   X_PMT_TO_BASE_XRATE           => null,
                                                   X_TRX_BASE_AMOUNT             => null,
                                                   X_ERRORS_BASE_AMOUNT          => null,
                                                   X_CHARGES_BASE_AMOUNT         => null,
                                                   X_MATCHED_FLAG                => null,
                                                   X_REV_PMT_HIST_ID             => null,
                                                   X_ORG_ID                      => p_org_id,
                                                   X_CREATION_DATE               => sysdate,
                                                   X_CREATED_BY                  => p_user_id,
                                                   X_LAST_UPDATE_DATE            => sysdate,
                                                   X_LAST_UPDATED_BY             => p_user_id,
                                                   X_LAST_UPDATE_LOGIN           => null,
                                                   X_PROGRAM_UPDATE_DATE         => null,
                                                   X_PROGRAM_APPLICATION_ID      => null,
                                                   X_PROGRAM_ID                  => null,
                                                   X_REQUEST_ID                  => null,
                                                   X_CALLING_SEQUENCE            => 'APXPAWKB (pay_sum_folder_pkg.insert_row)',
                                                   X_ACCOUNTING_EVENT_ID         => null,
                                                   x_invoice_adjustment_event_id => null);
     -- commit;
    exception
      when others then
        l_return_status := 'E22STAB040';
        l_return_mess   := 'Lỗi tạo history payment';
        l_return_detail := 'Lỗi hệ thống. Không tạo được history payment. Vui lòng liên hệ IT!  ' ||
                           sqlerrm;
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise v_invalid;
    end;
  
    begin
      select h.ACCOUNTING_EVENT_ID
        into v_accounting_event_id
        from ap_payment_history_all h
       where h.CHECK_ID = v_check_id
         and h.TRANSACTION_TYPE = v_transaction_type;
    exception
      when others then
        l_return_status := 'E22STAB041';
        l_return_mess   := 'Lỗi hệ thống!';
        l_return_detail := 'Không tồn tại accounting event id';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise v_invalid;
    end;
    for inv_rec in (select ai.INVOICE_ID,
                           ai.INVOICE_NUM,
                           ai.INVOICE_TYPE_LOOKUP_CODE,
                           ai.ACCTS_PAY_CODE_COMBINATION_ID,
                           ai.INVOICE_CURRENCY_CODE,
                           ai.SET_OF_BOOKS_ID
                      from ap_invoices_all ai
                     where ai.INVOICE_ID = p_invoice_id) loop
      v_account_liability_id := inv_rec.accts_pay_code_combination_id;
      v_amount               := v_payamount;
      v_invoice_type         := inv_rec.invoice_type_lookup_code;
      v_invoice_number       := inv_rec.invoice_num;
      begin
        select nvl(min(ps.payment_num), 1)
          into v_payment_num
          from ap_payment_schedules_all ps
         where 1 = 1
           and ps.AMOUNT_REMAINING <> 0
           and ps.INVOICE_ID = p_invoice_id;
      exception
        when others then
          v_payment_num := 1;
      end;
      select ap_invoice_payments_s.nextval
        into v_invoice_payment_id
        from dual;
      ap_pay_invoice_pkg.ap_pay_invoice(P_invoice_id                => p_invoice_id,
                                        P_check_id                  => v_check_id,
                                        P_payment_num               => nvl(v_payment_num,
                                                                           1),
                                        P_invoice_payment_id        => v_invoice_payment_id,
                                        P_old_invoice_payment_id    => null,
                                        P_period_name               => v_period_name,
                                        P_invoice_type              => inv_rec.invoice_type_lookup_code,
                                        P_accounting_date           => v_gldate,
                                        P_amount                    => v_payamount,
                                        P_discount_taken            => 0,
                                        P_discount_lost             => null,
                                        P_invoice_base_amount       => null,
                                        P_payment_base_amount       => null,
                                        P_accrual_posted_flag       => 'N',
                                        P_cash_posted_flag          => 'N',
                                        P_posted_flag               => 'N',
                                        P_set_of_books_id           => inv_rec.set_of_books_id,
                                        P_last_updated_by           => p_user_id,
                                        P_last_update_login         => p_user_id,
                                        P_currency_code             => inv_rec.invoice_currency_code,
                                        P_base_currency_code        => v_invoice_currency,
                                        P_exchange_rate             => v_ex_rate,
                                        P_exchange_rate_type        => v_ex_rate_type,
                                        P_exchange_date             => v_ex_date,
                                        P_ce_bank_acct_use_id       => v_bank_account_id,
                                        P_bank_account_num          => v_bank_account_num,
                                        P_bank_account_type         => null,
                                        P_bank_num                  => null,
                                        P_future_pay_posted_flag    => null,
                                        P_exclusive_payment_flag    => 'N',
                                        P_accts_pay_ccid            => inv_rec.accts_pay_code_combination_id,
                                        P_gain_ccid                 => null,
                                        P_loss_ccid                 => null,
                                        P_future_pay_ccid           => null,
                                        P_asset_ccid                => null,
                                        P_payment_dists_flag        => 'Y',
                                        P_payment_mode              => 'PAY',
                                        P_replace_flag              => 'N',
                                        P_attribute1                => null,
                                        P_attribute2                => null,
                                        P_attribute3                => null,
                                        P_attribute4                => null,
                                        P_attribute5                => null,
                                        P_attribute6                => null,
                                        P_attribute7                => null,
                                        P_attribute8                => null,
                                        P_attribute9                => null,
                                        P_attribute10               => null,
                                        P_attribute11               => null,
                                        P_attribute12               => null,
                                        P_attribute13               => null,
                                        P_attribute14               => null,
                                        P_attribute15               => null,
                                        P_attribute_category        => null,
                                        P_global_attribute1         => null,
                                        P_global_attribute2         => null,
                                        P_global_attribute3         => null,
                                        P_global_attribute4         => null,
                                        P_global_attribute5         => null,
                                        P_global_attribute6         => null,
                                        P_global_attribute7         => null,
                                        P_global_attribute8         => null,
                                        P_global_attribute9         => null,
                                        P_global_attribute10        => null,
                                        P_global_attribute11        => null,
                                        P_global_attribute12        => null,
                                        P_global_attribute13        => null,
                                        P_global_attribute14        => null,
                                        P_global_attribute15        => null,
                                        P_global_attribute16        => null,
                                        P_global_attribute17        => null,
                                        P_global_attribute18        => null,
                                        P_global_attribute19        => null,
                                        P_global_attribute20        => null,
                                        P_global_attribute_category => null,
                                        P_calling_sequence          => 'Pay invoice Forms <- Pre_insert trigger',
                                        P_accounting_event_id       => v_accounting_event_id,
                                        P_org_id                    => p_org_id);
     -- commit;
    end loop;
    -- cập nhật số payment document
    update ce_payment_documents v
       set v.LAST_ISSUED_DOCUMENT_NUMBER = v.LAST_ISSUED_DOCUMENT_NUMBER + 1
     where v.PAYMENT_DOCUMENT_ID = v_payment_document_id;
    begin
      select pc.CHECK_NUMBER
        into v_check_number
        from ap_checks_all pc
       where pc.CHECK_id = v_check_id;
    exception
      when others then
        v_check_number := null;
    end;
    begin
      select pip.INVOICE_PAYMENT_ID
        into v_invoice_payment_id
        from ap_invoice_payments_all pip
       where 1 = 1
         and pip.CHECK_ID = v_check_id
         and pip.INVOICE_ID = p_invoice_id
         and not exists (select 1
                from ap_checks_all pc
               where pc.CHECK_id = pip.CHECK_ID
                 and pc.STATUS_LOOKUP_CODE = 'VOID');
    exception
      when others then
        v_invoice_payment_id := null;
    end;
    if v_check_number is null then
      l_return_status := 'E22STAB042';
      l_return_mess   := 'Lỗi không tạo được payment!';
      l_return_detail := 'Không tạo được payment!';
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise v_invalid;
    end if;
    if v_invoice_payment_id is null then
      l_return_status := 'E22STAB043';
      l_return_mess   := 'Lỗi hệ thống!';
      l_return_detail := 'Tạo được payment ' || v_check_number ||
                         ', nhưng không apply được cho invoice ' ||
                         v_invoice_number;
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise v_invalid;
    end if;
   -- commit;
    /*begin
      select xte.ENTITY_ID
        into v_entity_id
        from xla_transaction_entities xte
       where xte.ENTITY_CODE = 'AP_PAYMENTS'
         and xte.SOURCE_ID_INT_1 = v_check_id
         and xte.APPLICATION_ID = 200;
    exception
      when others then
        v_entity_id := null;
    end;*/
    /*dev_cpm_prepay_pkg.Create_Account(p_Application_Id  => 200,
                                      p_Entity_Id       => v_entity_id,
                                      p_Accounting_Mode => 'D',
                                      x_Return_Status   => l_return_status,
                                      x_Return_Mess     => l_return_mess);
    if l_return_status <> 'S' then
      l_return_status := 'E22STAB044';
      l_return_mess   := 'Tạo được payment ' || v_check_number ||
                         ', nhưng không tạo được bút toán do lỗi ' ||
                         l_return_mess;
      l_return_detail := 'Tạo được payment ' || v_check_number ||
                         ', nhưng không tạo được bút toán do lỗi ' ||
                         l_return_mess;
      x_status        := l_return_status;
      x_mess          := l_return_mess;
      x_detail        := l_return_detail;
      raise v_invalid;
    end if;*/
    if x_status = 'S' then
      x_payment_number := v_check_number;
    end if;
  exception
    when v_invalid then
      rollback;
  end create_payment;
  ------------------
  procedure apply_prepayment(p_data_id    number,
                             p_invoice_id number,
                             p_user_id    number,
                             x_status     out varchar2,
                             x_mess       out varchar2,
                             x_detail     out varchar2) is
    l_Result_Boolean   boolean;
    l_pre_invoice_id   number;
    l_Prepay_Dist_Info Ap_Prepay_Pkg.Prepay_Dist_Tab_Type;
    l_applyDate        date;
    v_Acct_Period      varchar2(200);
    l_Error_Message    varchar2(4000);
    l_org_id           number;
    l_exception        exception;
    l_return_status    varchar2(20);
    l_return_mess      varchar2(4000);
    l_return_detail    varchar2(4000);
  begin
  l_return_status := 'S';
    for pre in (select applyAmount,
                       applyDate,
                       applyPaymentNum,
                       1 line_number
                
                  from dev.dev_cpm_api_data j,
                       JSON_TABLE(j.json_data,
                                  '$.Invoice'
                                  COLUMNS(NESTED PATH
                                          '$.ApplicationPrepayment[*]'
                                          COLUMNS(applyAmount number path
                                                  '$.applyAmount',
                                                  applyDate varchar2(200) path
                                                  '$.applyDate',
                                                  applyPaymentNum
                                                  varchar2(200) path
                                                  '$.applyPaymentNum'))) t
                 where j.data_id = p_data_id) loop
      select ai.INVOICE_ID, ai.ORG_ID
        into l_pre_invoice_id, l_org_id
        from ap_invoices_all ai
       where ai.ATTRIBUTE10 = pre.applypaymentnum;
      l_applyDate      := to_date(pre.applydate, 'DD-MM-RRRR');
      v_Acct_Period    := to_char(l_applyDate, 'MM-RR');
      l_Result_Boolean := Ap_Prepay_Pkg.Apply_Prepay_Line(p_Prepay_Invoice_Id   => l_pre_invoice_id,
                                                          p_Prepay_Line_Num     => pre.line_number,
                                                          p_Prepay_Dist_Info    => l_Prepay_Dist_Info,
                                                          p_Prorate_Flag        => 'Y',
                                                          p_Invoice_Id          => p_Invoice_Id,
                                                          p_Invoice_Line_Number => NULL,
                                                          p_Apply_Amount        => pre.applyamount,
                                                          p_Gl_Date             => l_applyDate,
                                                          p_Period_Name         => v_Acct_Period,
                                                          p_Prepay_Included     => 'N',
                                                          p_User_Id             => p_User_Id,
                                                          p_Last_Update_Login   => 0,
                                                          p_Calling_Sequence    => 'Apply Prepayment Form',
                                                          p_Calling_Mode        => 'PREPAYMENT APPLICATION',
                                                          p_Error_Message       => l_Error_Message);
      if l_Result_Boolean = false then
        l_return_Status := 'E22STAS051';
        l_return_mess   := 'Lỗi Apply hóa đơn!';
        l_return_detail := 'Không Apply được cho số hóa đơn: ' ||
                           pre.applypaymentnum ||
                           ' Liên hệ kỹ thuật hệ thống Oracle GL!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise l_exception;
        exit;
      else
        l_return_status := 'S';
        l_return_mess   := 'Apply thành công!';
        l_return_detail := 'Apply thành công!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
      
      end if;
    end loop;
    if l_return_Status = 'S' then
    validate_invoice(p_user_id       => p_user_id,
                     p_org_id        => l_org_id,
                     p_invoice_id    => p_invoice_id,
                     x_return_status => l_return_status,
                     x_return_mess   => l_return_mess,
                     x_return_detail => l_return_detail);
    else
      x_status := l_return_status;
      x_mess   := l_return_mess;
      x_detail := l_return_detail;
    end if;
  exception
    when l_exception then
      rollback;
  end;
  ------------------
  procedure import_journal(p_data_id    number,
                           p_invoice_id number,
                           p_org_id     number,
                           p_user_Id    number,
                           x_document   out varchar2,
                           x_status     out varchar2,
                           x_mess       out varchar2,
                           x_detail     out varchar2) is
    v_ledger_name            varchar2(200) := 'MF_SOB';
    ERR                      Exception;
    l_num                    number;
    v_budgetary_control_flag varchar2(1);
    v_je_approval_flag       varchar2(1);
    v_je_batch_id            number;
    seq_num                  fnd_profile_option_values.PROFILE_OPTION_VALUE%type;
    v_period_set_name        gl_ledgers.PERIOD_SET_NAME%type;
    v_accounted_period_type  gl_ledgers.ACCOUNTED_PERIOD_TYPE%type;
    v_chart_of_accounts_id   gl_ledgers.CHART_OF_ACCOUNTS_ID%type;
    v_ledger_id              gl_ledgers.LEDGER_ID%type;
    v_led_currency_code      gl_ledgers.CURRENCY_CODE%type;
    --
    v_default_effective_date gl_je_headers.DEFAULT_EFFECTIVE_DATE%type;
    v_period_name            gl_je_headers.PERIOD_NAME%type;
  
    v_actual_flag          varchar2(1) := 'A';
    v_average_journal_flag gl_je_batches.AVERAGE_JOURNAL_FLAG%type := 'N';
    v_je_header_id         number;
    --v_check_period         number;
    l_return_status varchar2(4000);
    l_return_mess   varchar2(4000);
    l_return_detail varchar2(4000);
    --l_org_close_period     varchar2(4000);
    v_concat_seg  varchar2(400);
    v_resp_id     number;
    v_exType      varchar2(200) := 'User';
    v_category    varchar2(200) := 'MC_API_CPM';
    v_batch_name  varchar2(100);
    v_invoice_num varchar2(30);
    v_ccid        number;
    l_ccid        number;
    v_segment1    varchar2(30);
  begin
    x_status := 'S';
    begin
      select frv.RESPONSIBILITY_ID
        into v_resp_id
        from fnd_responsibility_vl frv
       where frv.APPLICATION_ID = 101
         and frv.RESPONSIBILITY_KEY = 'GL_NHAP_LIEU';
    exception
      when others then
        v_resp_id := null;
    end;
    select ai.INVOICE_NUM, ai.ACCTS_PAY_CODE_COMBINATION_ID
      into v_invoice_num, v_ccid
      from ap_invoices_all ai
     where ai.INVOICE_ID = p_invoice_id;
    
    v_batch_name := 'Hóa đơn quà tặng ' || v_invoice_num;
  
    for journal in (select giftInvoice,
                           glDate,
                           invoiceCur,
                           exRate,
                           docNumCpm/*,
                           segment1,
                           segment2,
                           segment3,
                           segment4Dr,
                           segment4Cr,
                           segment11,
                           amount,
                           budget,
                           campaign,
                           fromDate,
                           toDate,
                           app,
                           partner,
                           customer,
                           employee*/
                      from dev.dev_cpm_api_data j,
                           JSON_TABLE(j.json_data,
                                      '$' COLUMNS(giftInvoice varchar2(200) path
                                              '$.gifInvoice',
                                              glDate varchar2(200) path
                                              '$.Invoice.glDate',
                                              invoiceCur varchar2(20) path
                                              '$.Invoice.invoiceCur',
                                              exRate varchar2(200) path
                                              '$.Invoice.exRate',
                                              docNumCpm varchar2(200) path
                                              '$.Invoice.docNumCpm'/*,
                                              segment1 varchar2(30) path
                                              '$.Journal.segment1',
                                              segment2 varchar2(30) path
                                              '$.Journal.segment2',
                                              segment3 varchar2(30) path
                                              '$.Journal.segment3',
                                              segment4Dr varchar2(30) path
                                              '$.Journal.segment4Dr',
                                              segment4Cr varchar2(30) path
                                              '$.Journal.segment4Cr',
                                              segment11 varchar2(30) path
                                              '$.Journal.segment11',
                                              amount number path
                                              '$.Journal.amount',
                                              budget varchar2(200) path
                                              '$.Journal.budget',
                                              campaign varchar2(200) path
                                              '$.Journal.campaign',
                                              fromDate varchar2(200) path
                                              '$.Journal.fromDate',
                                              toDate varchar2(200) path
                                              '$.Journal.toDate',
                                              app varchar2(200) path
                                              '$.Journal.app',
                                              partner varchar2(200) path
                                              '$.Journal.partner',
                                              customer varchar2(200) path
                                              '$.Journal.customer',
                                              employee varchar2(200) path
                                              '$.Journal.employee'*/)) t
                     where j.data_id = p_data_id) loop
      v_default_effective_date := to_date(journal.gldate, 'DD-MM-RRRR');
      v_period_name            := to_char(v_default_effective_date, 'MM-RR');
      select decode(lgr.ENABLE_BUDGETARY_CONTROL_FLAG, 'Y', 'Y', 'N') budgetary_control_flag,
             decode(lgr.ENABLE_JE_APPROVAL_FLAG, 'Y', 'Y', 'N') je_approval_flag,
             lgr.PERIOD_SET_NAME,
             lgr.ACCOUNTED_PERIOD_TYPE,
             lgr.CHART_OF_ACCOUNTS_ID,
             lgr.CURRENCY_CODE,
             lgr.LEDGER_ID
        into v_budgetary_control_flag,
             v_je_approval_flag,
             v_period_set_name,
             v_accounted_period_type,
             v_chart_of_accounts_id,
             v_led_currency_code,
             v_ledger_id
        from gl_ledgers lgr
       where lgr.NAME = v_ledger_name;
      if (SQL%ROWCOUNT <> 1) then
        raise err;
      end if;
      fnd_global.APPS_INITIALIZE(p_user_id, v_resp_id, 101);
      select gl_je_batches_s.nextval into v_je_batch_id from dual;
      if (v_je_approval_flag = 'Y') then
        select g.journal_approval_flag
          into v_je_approval_flag
          from gl_je_sources g
         where g.je_source_name = 'Manual';
      end if;
      insert into gl_je_batches
        (JE_BATCH_ID,
         chart_of_accounts_id,
         period_set_name,
         accounted_period_type,
         name,
         status,
         status_verified,
         budgetary_control_status,
         actual_flag,
         average_journal_flag,
         default_effective_date,
         default_period_name,
         date_created,
         description,
         org_id,
         approval_status_code,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         LAST_UPDATE_LOGIN)
        select v_je_batch_id,
               v_chart_of_accounts_id,
               v_period_set_name,
               v_accounted_period_type,
               v_batch_name,
               'U',
               'N',
               decode(v_budgetary_control_flag, 'Y', 'R', 'N'),
               v_actual_flag,
               v_average_journal_flag,
               v_default_effective_date,
               v_period_name,
               sysdate,
               v_batch_name,
               p_org_id,
               decode(v_je_approval_flag, 'Y', 'R', 'Z'),
               sysdate,
               p_user_id,
               sysdate,
               p_user_id,
               0
          from dual;
      if (SQL%ROWCOUNT <> 1) then
        raise err;
      end if;
      declare
        v_je_category     varchar2(25);
        v_currency_code   varchar2(15);
        v_conversion_date date;
        v_conversion_type varchar2(25);
        v_conversion_rate number;
        --v_rev_method      varchar2(1);
        --v_rev_period      varchar2(15);
        --v_rev_date        date;
      begin
        select t.je_category_name
          into v_je_category
          from gl_je_categories t
         where t.user_je_category_name = v_category;
        v_currency_code   := journal.invoicecur;
        v_conversion_date := sysdate;
        v_conversion_type := v_exType;
        v_conversion_rate := nvl(journal.exrate, 1);
        select gl_je_headers_s.nextval into v_je_header_id from dual;
        insert into gl_je_headers
          (JE_BATCH_ID,
           JE_HEADER_ID,
           LEDGER_ID,
           je_category,
           JE_SOURCE,
           DEFAULT_EFFECTIVE_DATE,
           period_name,
           name,
           currency_code,
           status,
           date_created,
           multi_bal_seg_flag,
           ACTUAL_FLAG,
           CONVERSION_FLAG,
           encumbrance_type_id,
           budget_version_id,
           accrual_rev_flag,
           ACCRUAL_REV_PERIOD_NAME,
           ACCRUAL_REV_CHANGE_SIGN_FLAG,
           DESCRIPTION,
           CONTROL_TOTAL,
           CURRENCY_CONVERSION_type,
           CURRENCY_CONVERSION_DATE,
           CURRENCY_CONVERSION_RATE,
           ussgl_transaction_code,
           tax_status_code,
           reference_date,
           CONTEXT,
           attribute1,
           CREATION_DATE,
           created_by,
           last_update_date,
           last_updated_by,
           last_update_login)
          select v_je_batch_id,
                 v_je_header_id,
                 v_ledger_id,
                 v_je_category,
                 'Manual',
                 v_default_effective_date,
                 v_period_name,
                 v_batch_name,
                 v_currency_code,
                 'U',
                 sysdate,
                 'N',
                 v_actual_flag,
                 null conversion_flag,
                 null encumbrance_type_id,
                 null budget_version_id,
                 decode(v_period_name, null, 'N', 'Y'),
                 v_period_name,
                 'Y',
                 v_batch_name,
                 null control_total,
                 v_conversion_type,
                 v_conversion_date,
                 v_conversion_rate,
                 null ussgll_transaction_code,
                 'N',
                 null reference_date,
                 'API CPM',
                 journal.docnumcpm,
                 sysdate,
                 p_user_id,
                 sysdate,
                 p_user_id,
                 0
            from dual;
        if (SQL%ROWCOUNT <> 1) then
          raise err;
        end if;
      end;
      l_num        := 1;
      for line in (select segment1,
                           segment2,
                           segment3,
                           segment4,
                           segment5,
                           segment6,
                           segment7,
                           segment8,
                           segment9,
                           segment10,
                           segment11,
                           amountDr,
                           amountCr,
                           budget,
                           campaign,
                           to_char(to_date(fromDate,'DD-MM-YYYY'),'RRRR/MM/DD HH24:MI:SS') fromDate,
                           to_char(to_date(toDate,'DD-MM-YYYY'),'RRRR/MM/DD HH24:MI:SS') toDate,
                           app,
                           partner,
                           customer,
                           employee
                      from dev.dev_cpm_api_data j,
                           JSON_TABLE(j.json_data,
                                      '$.Journal' COLUMNS(NESTED PATH '$.LineJournal[*]'
                                      COLUMNS(
                                              segment1 varchar2(30) path
                                              '$.segment1',
                                              segment2 varchar2(30) path
                                              '$.segment2',
                                              segment3 varchar2(30) path
                                              '$.segment3',
                                              segment4 varchar2(30) path
                                              '$.segment4',
                                              segment5 varchar2(30) path
                                              '$.segment5',
                                              segment6 varchar2(30) path
                                              '$.segment6',
                                              segment7 varchar2(30) path
                                              '$.segment7',
                                              segment8 varchar2(30) path
                                              '$.segment8',
                                              segment9 varchar2(30) path
                                              '$.segment9',
                                              segment10 varchar2(30) path
                                              '$.segment10',
                                              segment11 varchar2(30) path
                                              '$.segment11',
                                              amountDr number path
                                              '$.amountDr',
                                              amountCr number path
                                              '$.amountCr',
                                              budget varchar2(200) path
                                              '$.budget',
                                              campaign varchar2(200) path
                                              '$.campaign',
                                              fromDate varchar2(200) path
                                              '$.fromDate',
                                              toDate varchar2(200) path
                                              '$.toDate',
                                              app varchar2(200) path
                                              '$.app',
                                              partner varchar2(200) path
                                              '$.partner',
                                              customer varchar2(200) path
                                              '$.customer',
                                              employee varchar2(200) path
                                              '$.employee'))) t
                     where j.data_id = p_data_id) loop
      
      v_segment1 := line.segment1;
      v_concat_seg := line.segment1 || '.' || line.segment2 || '.' ||
                      line.segment3 || '.' || line.segment11 || '.' ||
                      line.segment5 || '.' || line.segment4 || '.' ||
                      line.segment6 || '.' || line.segment7 || '.' || line.segment8 || '.' ||
                      line.segment9 || '.' || line.segment10;
      dev_cpm_api_pkg.check_ccid(p_coa_id     => v_chart_of_accounts_id,
                                 p_concat_seg => v_concat_seg,
                                 x_ccid       => l_ccid,
                                 x_status     => l_return_status,
                                 x_mess       => l_return_mess,
                                 x_detail     => l_return_detail);
      insert into gl_je_lines
        (JE_HEADER_ID,
         JE_LINE_NUM,
         ledger_id,
         CODE_COMBINATION_ID,
         PERIOD_NAME,
         EFFECTIVE_DATE,
         STATUS,
         ENTERED_DR,
         ENTERED_CR,
         ACCOUNTED_DR,
         ACCOUNTED_CR,
         DESCRIPTION,CONTEXT,
         ATTRIBUTE9,
         ATTRIBUTE2,
         ATTRIBUTE3,
         ATTRIBUTE4,
         ATTRIBUTE5,
         ATTRIBUTE6,
         ATTRIBUTE7,
         ATTRIBUTE8,
         CREATION_DATE,
         CREATED_BY,
         LAST_UPDATE_DATE,
         LAST_UPDATED_BY,
         LAST_UPDATE_LOGIN)
        select v_je_header_Id,
               l_num,
               v_ledger_id,
               l_ccid,
               v_period_name,
               v_default_effective_date,
               'U',
               line.amountDr,
               line.amountcr,
               line.amountDr,
               line.amountcr,
               v_batch_name,
               'Financial Information',
               line.budget,
               line.campaign,
               line.fromdate,
               line.todate,
               line.app,
               line.partner,
               line.customer,
               line.employee,
               sysdate,
               p_user_id,
               sysdate,
               p_user_id,
               0
          from dual;
      l_num := l_num + 1;
      
          end loop;
          insert into gl_je_segment_values
        (JE_HEADER_ID,
         SEGMENT_TYPE_CODE,
         SEGMENT_VALUE,
         CREATED_BY,
         CREATION_DATE,
         LAST_UPDATED_BY,
         LAST_UPDATE_DATE,
         LAST_UPDATE_LOGIN)
        select v_je_header_id,
               'B',
               v_segment1,
               p_user_id,
               sysdate,
               p_user_id,
               sysdate,
               0
          from dual;
      update gl_je_headers gjh
         set (gjh.RUNNING_TOTAL_DR,
              gjh.RUNNING_TOTAL_CR,
              gjh.RUNNING_TOTAL_ACCOUNTED_DR,
              gjh.RUNNING_TOTAL_ACCOUNTED_CR) =
             (select sum(nvl(gjl.ENTERED_DR, 0)),
                     sum(nvl(gjl.ENTERED_CR, 0)),
                     sum(nvl(gjl.ACCOUNTED_DR, 0)),
                     sum(nvl(gjl.ACCOUNTED_CR, 0))
                from gl_je_lines gjl
               where gjl.JE_HEADER_ID = gjh.JE_HEADER_ID)
       where gjh.JE_HEADER_ID = v_je_header_id;
      update gl_je_batches gjb
         set (gjb.RUNNING_TOTAL_DR,
              gjb.RUNNING_TOTAL_CR,
              gjb.RUNNING_TOTAL_ACCOUNTED_DR,
              gjb.RUNNING_TOTAL_ACCOUNTED_CR) =
             (select sum(nvl(gjh.RUNNING_TOTAL_DR, 0)),
                     sum(nvl(gjh.RUNNING_TOTAL_CR, 0)),
                     sum(nvl(gjh.RUNNING_TOTAL_ACCOUNTED_DR, 0)),
                     sum(nvl(gjh.RUNNING_TOTAL_ACCOUNTED_CR, 0))
                from gl_je_headers gjh
               where gjh.JE_BATCH_ID = gjb.JE_BATCH_ID)
       where gjb.JE_BATCH_ID = v_je_batch_id;
      declare
        je_category gl_je_headers.JE_CATEGORY%type;
        lgr_id      gl_je_headers.LEDGER_ID%type;
        seq_id      number;
        seq_val     number;
        row_id      rowid;
        seq_result  number;
        je_name     gl_je_headers.name%type;
        cursor new_journals is
          select rowid, ledger_id, je_category, name
            from gl_je_headers
           where je_header_id = v_je_header_id;
      begin
        open new_journals;
        loop
          seq_id  := null;
          seq_val := null;
          fetch new_journals
            into row_id, lgr_id, je_category, je_name;
          exit when new_journals%NOTFOUND;
          seq_result := fnd_seqnum.get_seq_val(app_id        => 101,
                                               cat_code      => je_category,
                                               sob_id        => lgr_id,
                                               met_code      => 'A',
                                               trx_date      => v_default_effective_date,
                                               seq_val       => seq_val,
                                               docseq_id     => seq_id,
                                               suppress_warn => 'Y');
          if seq_result = 0 and seq_val is not null then
            update gl_je_headers gl
               set gl.DOC_SEQUENCE_ID    = seq_id,
                   gl.DOC_SEQUENCE_VALUE = seq_val
             where gl.JE_HEADER_ID = v_je_header_id;
            x_document := seq_val;
          elsif seq_num = 'A' then
            raise err;
          end if;
        end loop;
        close new_journals;
      end;
      --fnd_concurrent.AF_COMMIT;
      --commit;
    
    end loop;
  exception
    when err then
      rollback;
  end import_journal;
  ------------------
  PROCEDURE sync_standard(p_data_id NUMBER,
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
      l_return_status := 'E22STAV052';
      l_return_mess   := 'Lỗi Cấu trúc json!';
      l_return_detail := 'Dữ liệu tích hợp sai cấu trúc json! Liên hệ kỹ thuật hệ thống CPM!';
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
      l_return_status := 'E22STAS053';
      l_return_mess   := 'Lỗi tại UserName tạo chứng từ!';
      l_return_detail := 'User tạo chứng từ không được để trống! Liên hệ kỹ thuật hệ thống CPM!';
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
        l_return_status := 'E22STAV054';
        l_return_mess   := 'Lỗi tại tên User tạo chứng từ!';
        l_return_detail := 'User tạo chứng từ chưa được khai báo hoặc đã hết hiệu lực tại Oracle GL!';
        x_status        := l_return_status;
        x_mess          := l_return_mess;
        x_detail        := l_return_detail;
        raise l_Exception;
      end if;
    end if;
    check_standard(p_data_id,
                   l_user_id,
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
  
   -- COMMIT;
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
      validate_invoice(p_user_id       => l_user_id,
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
  
    /*SELECT Xte.Entity_Id
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
    end if;*/
  
    create_tax_manual(p_data_id,
                      l_user_id,
                      l_invoice_id,
                      l_return_status,
                      l_return_mess,
                      l_return_detail);
    begin
      select isApply, giftInvoice, isPayment
        into l_isApply, l_giftInvoice, l_isPayment
        FROM dev.dev_cpm_api_data j,
             JSON_TABLE(j.json_data,
                        '$'
                        COLUMNS(isApply varchar2(1) path '$.Invoice.isApply',
                                isPayment varchar2(1) path
                                '$.isPayment',
                                giftInvoice varchar2(1) path '$.giftInvoice')) t
       where j.data_id = p_data_id;
    exception
      when others then
        l_isApply := null;
    end;
    if l_isPayment = 'Y' then
      create_payment(p_data_id        => p_data_id,
                     p_invoice_id     => l_invoice_id,
                     p_org_id         => l_org_id,
                     p_user_id        => l_user_id,
                     x_payment_number => l_payment_number,
                     x_status         => l_return_status,
                     x_mess           => l_return_mess,
                     x_detail         => l_return_detail);
      if l_return_status <> 'S' then
        x_status := l_return_status;
        x_mess   := l_return_mess;
        x_detail := l_return_detail;
        raise l_Exception;
      end if;
    end if;
    if l_isApply = 'Y' then
      apply_prepayment(p_data_id    => p_data_id,
                       p_invoice_id => l_invoice_id,
                       p_user_id    => l_user_id,
                       x_status     => l_return_status,
                       x_mess       => l_return_mess,
                       x_detail     => l_return_detail);
      
      if l_return_status <> 'S' then
        x_status := l_return_status;
        x_mess   := l_return_mess;
        x_detail := l_return_detail;
        raise l_exception;
      end if;
    end if;
    if l_giftInvoice = 'Y' then
      dev_cpm_standard_pkg.import_journal(p_data_id    => p_data_id,
                                          p_invoice_id => l_invoice_id,
                                          p_org_id     => l_org_id,
                                          p_user_Id    => l_user_id,
                                          x_document   => l_document,
                                          x_status     => l_return_status,
                                          x_mess       => l_return_mess,
                                          x_detail     => l_return_detail);
      if l_return_status <> 'S' then
        x_status := l_return_status;
        x_mess   := l_return_mess;
        x_detail := l_return_detail;
        raise l_exception;
      end if;
    end if;
    if l_return_status = 'S' then
      commit;
      x_status := 'S';
      x_mess   := 'Tạo invoice thành công!';
      x_detail := 'Invoice num: ' || l_invoice_num || case
                    when l_isPayment = 'Y' then
                     ', Payment num: ' || l_payment_number
                  end || case
                    when l_giftInvoice = 'Y' then
                     ', Journal Doc Num: ' || l_document
                  end;
    
    end if;
  exception
    when l_exception then
      rollback;
  END;
end dev_cpm_standard_pkg;
/
