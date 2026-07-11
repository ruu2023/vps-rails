import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static targets = ["canvas", "tab"]
  static values = {
    monthlyLabels: Array,
    monthlyIncome: Array,
    monthlyExpense: Array,
    categoryLabels: Array,
    categoryAmounts: Array
  }

  connect() {
    this.mode = "monthly"
    this.chart = new Chart(this.canvasTarget, this.configFor("monthly"))
  }

  disconnect() {
    this.chart?.destroy()
  }

  switchTab(event) {
    const mode = event.currentTarget.dataset.mode
    if (mode === this.mode) return

    this.mode = mode
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.mode === mode
      tab.classList.toggle("bg-kaikei-primary", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("text-kaikei-text-subtle", !active)
    })

    this.chart.destroy()
    this.chart = new Chart(this.canvasTarget, this.configFor(mode))
  }

  configFor(mode) {
    if (mode === "category") {
      return {
        type: "pie",
        data: {
          labels: this.categoryLabelsValue,
          datasets: [ { data: this.categoryAmountsValue, backgroundColor: [ "#3a7bd5", "#28a745", "#dc3545", "#ffc107", "#666666" ] } ]
        },
        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: "bottom" } } }
      }
    }

    return {
      type: "bar",
      data: {
        labels: this.monthlyLabelsValue,
        datasets: [
          { label: "収入", data: this.monthlyIncomeValue, backgroundColor: "#28a745" },
          { label: "支出", data: this.monthlyExpenseValue, backgroundColor: "#dc3545" }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: { y: { beginAtZero: true } },
        plugins: { legend: { position: "top" } }
      }
    }
  }
}
