require "csv"
require "prawn"
require "prawn/table"

class Kaikei::ExportsController < Kaikei::BaseController
  def new
  end

  def create
    start_date = params[:start_date]
    end_date = params[:end_date]
    kind = params[:kind] # "transactions", "journal", or "categories"
    format = params[:format] # "csv", "excel", or "pdf"

    headers_row, rows = kind == "categories" ? category_export_data : transaction_export_data(kind, start_date, end_date)

    case format
    when "excel"
      send_data build_excel(headers_row, rows), filename: "#{export_filename(kind, start_date, end_date)}.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    when "pdf"
      send_data build_pdf(KIND_LABELS.fetch(kind, kind), headers_row, rows),
        filename: "#{export_filename(kind, start_date, end_date)}.pdf", type: "application/pdf"
    else
      send_data build_csv(headers_row, rows), filename: "kaikei_export.csv", type: "text/csv"
    end
  end

  private

  KIND_LABELS = { "transactions" => "取引データ", "journal" => "仕訳帳", "categories" => "科目設定" }.freeze

  TYPE_LABELS = { "income" => "収入", "expense" => "支出" }.freeze

  JP_FONT_PATH = Rails.root.join("app/assets/fonts/NotoSansJP-Regular.ttf")

  def export_filename(kind, start_date, end_date)
    kind == "categories" ? KIND_LABELS.fetch(kind, kind) : "#{KIND_LABELS.fetch(kind, kind)}_#{start_date}_#{end_date}"
  end

  def transaction_export_data(kind, start_date, end_date)
    transactions = current_user.kaikei_transactions
      .includes(:category, :payment_method)
      .where(date: start_date..end_date)
      .order(:date)

    headers_row = kind == "journal" ? journal_headers : transaction_headers
    [ headers_row, build_rows(transactions, kind) ]
  end

  def category_export_data
    categories = current_user.kaikei_categories.order(:sort_order)
    rows = categories.map { |c| [ c.name, TYPE_LABELS.fetch(c.default_type, c.default_type), c.sort_order ] }
    [ category_headers, rows ]
  end

  def transaction_headers
    [ "日付", "科目", "支払方法", "取引先", "収支区分", "金額", "メモ" ]
  end

  def journal_headers
    [ "取引日", "借方", "借方金額", "貸方", "貸方金額", "摘要" ]
  end

  def category_headers
    [ "科目名", "収支区分", "表示順" ]
  end

  def build_rows(transactions, kind)
    transactions.map do |t|
      if kind == "journal"
        debit = t.type == "income" ? t.payment_method&.name : t.category.name
        credit = t.type == "income" ? t.category.name : t.payment_method&.name
        [ t.date, debit, t.amount, credit, t.amount, journal_summary(t) ]
      else
        [ t.date, t.category.name, t.payment_method&.name, t.client_name, TYPE_LABELS.fetch(t.type, t.type), t.amount, t.memo ]
      end
    end
  end

  def journal_summary(transaction)
    client_name = transaction.client_name.presence
    memo = transaction.memo.presence

    if client_name && memo
      "#{client_name} : #{memo}"
    else
      client_name || memo || ""
    end
  end

  def build_csv(headers_row, rows)
    csv = CSV.generate do |csv|
      csv << headers_row
      rows.each { |row| csv << row }
    end
    "﻿#{csv}"
  end

  def build_pdf(title, headers_row, rows)
    Prawn::Document.new(page_layout: :landscape, margin: 36) do |pdf|
      pdf.font_families.update("NotoSansJP" => { normal: JP_FONT_PATH })
      pdf.font "NotoSansJP"

      pdf.text title, size: 16
      pdf.move_down 12
      pdf.table [ headers_row, *rows ], header: true, width: pdf.bounds.width do
        row(0).background_color = "EEEEEE"
        cells.size = 9
        cells.padding = [ 4, 6 ]
      end
    end.render
  end

  def build_excel(headers_row, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "export") do |sheet|
      sheet.add_row headers_row
      rows.each { |row| sheet.add_row row }
      sheet.column_widths(*column_widths(headers_row, rows))
    end
    package.to_stream.read
  end

  def column_widths(headers_row, rows)
    (0...headers_row.size).map do |i|
      ([ headers_row, *rows ].map { |row| display_width(row[i]) }.max || 0) + 2
    end
  end

  def display_width(value)
    value.to_s.each_char.sum { |char| full_width_char?(char) ? 2 : 1 }
  end

  def full_width_char?(char)
    code = char.ord
    (0x1100..0x115F).cover?(code) ||
      (0x2E80..0xA4CF).cover?(code) ||
      (0xAC00..0xD7A3).cover?(code) ||
      (0xF900..0xFAFF).cover?(code) ||
      (0xFF00..0xFF60).cover?(code) ||
      (0xFFE0..0xFFE6).cover?(code)
  end
end
