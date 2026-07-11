import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "type", "typeOption", "paymentMethod"]

  connect() {
    if (!this.typeTarget.value) {
      this.typeTarget.value = "income"
    }

    this.refreshToggleUI()
    this.filterOptions()
  }

  syncType() {
    const selected = this.categoryTarget.selectedOptions[0]
    const defaultType = selected?.dataset.defaultType
    if (defaultType) {
      this.typeTarget.value = defaultType
      this.refreshToggleUI()
      this.filterOptions()
    }
  }

  selectType(event) {
    const newType = event.currentTarget.dataset.type
    if (this.typeTarget.value === newType) return

    this.typeTarget.value = newType
    this.refreshToggleUI()
    this.filterOptions()
  }

  refreshToggleUI() {
    const currentType = this.typeTarget.value

    this.typeOptionTargets.forEach((button) => {
      const isActive = button.dataset.type === currentType
      const activeClasses = button.dataset.type === "income"
        ? [ "bg-kaikei-income", "text-white" ]
        : [ "bg-kaikei-expense", "text-white" ]
      const inactiveClasses = button.dataset.type === "income"
        ? [ "bg-white", "text-kaikei-income" ]
        : [ "bg-white", "text-kaikei-expense" ]

      button.classList.remove(...activeClasses, ...inactiveClasses)
      button.classList.add(...(isActive ? activeClasses : inactiveClasses))
    })
  }

  filterOptions() {
    const currentType = this.typeTarget.value

    let categorySelectedHidden = false
    Array.from(this.categoryTarget.options).forEach((option) => {
      const optionType = option.dataset.defaultType
      const matches = !optionType || optionType === currentType
      option.hidden = !matches
      if (option.selected && !matches) categorySelectedHidden = true
    })
    if (categorySelectedHidden) this.categoryTarget.value = ""

    let paymentMethodSelectedHidden = false
    Array.from(this.paymentMethodTarget.options).forEach((option) => {
      const optionType = option.dataset.type
      const matches = !optionType || optionType === currentType
      option.hidden = !matches
      if (option.selected && !matches) paymentMethodSelectedHidden = true
    })
    if (paymentMethodSelectedHidden) this.paymentMethodTarget.value = ""
  }
}
