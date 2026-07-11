import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static values = { labels: Array, income: Array, expense: Array }

  connect() {
    this.chart = new Chart(this.element, {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: [
          { label: "収入", data: this.incomeValue, backgroundColor: "#4caf50" },
          { label: "支出", data: this.expenseValue, backgroundColor: "#f44336" }
        ]
      },
      options: {
        responsive: true,
        scales: { y: { beginAtZero: true } }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
