require "csv"

class Kaikei::ExportsController < Kaikei::BaseController
  def new
  end

  def create
    start_date = params[:start_date]
    end_date = params[:end_date]
    kind = params[:kind] # "transactions" or "journal"
    format = params[:format] # "csv" or "excel"

    transactions = current_user.kaikei_transactions
      .includes(:category, :payment_method)
      .where(date: start_date..end_date)
      .order(:date)

    rows = build_rows(transactions, kind)
    headers_row = kind == "journal" ? journal_headers : transaction_headers

    if format == "excel"
      send_data build_excel(headers_row, rows), filename: "kaikei_export.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else
      send_data build_csv(headers_row, rows), filename: "kaikei_export.csv", type: "text/csv"
    end
  end

  private

  def transaction_headers
    [ "日付", "科目", "支払方法", "取引先", "収支区分", "金額", "メモ" ]
  end

  def journal_headers
    [ "日付", "借方科目", "借方金額", "貸方科目", "貸方金額" ]
  end

  def build_rows(transactions, kind)
    transactions.map do |t|
      if kind == "journal"
        if t.type == "income"
          [ t.date, t.payment_method&.name, t.amount, t.category.name, nil ]
        else
          [ t.date, t.category.name, t.amount, t.payment_method&.name, nil ]
        end
      else
        [ t.date, t.category.name, t.payment_method&.name, t.client_name, t.type, t.amount, t.memo ]
      end
    end
  end

  def build_csv(headers_row, rows)
    csv = CSV.generate do |csv|
      csv << headers_row
      rows.each { |row| csv << row }
    end
    "﻿#{csv}"
  end

  def build_excel(headers_row, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "export") do |sheet|
      sheet.add_row headers_row
      rows.each { |row| sheet.add_row row }
    end
    package.to_stream.read
  end
end
