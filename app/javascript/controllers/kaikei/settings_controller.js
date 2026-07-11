import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tabButton", "panel",
    "categoryModal", "categoryModalTitle", "categoryForm", "categoryMethodField",
    "categoryNameField", "categoryTypeField", "categoryIconField", "categoryIconPreview", "iconOption",
    "deleteCategoryModal", "categoryDeleteForm"
  ]
  static values = { categoriesPath: String, activeTab: String }

  connect() {
    this.activateTab(this.activeTabValue || "export")
  }

  showTab(event) {
    this.activateTab(event.currentTarget.dataset.tab)
  }

  activateTab(tab) {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tab !== tab
    })

    this.tabButtonTargets.forEach((button) => {
      const active = button.dataset.tab === tab
      button.classList.toggle("bg-kaikei-primary/10", active)
      button.classList.toggle("text-kaikei-primary", active)
      button.classList.toggle("text-kaikei-text-muted", !active)
    })
  }

  help() {
    alert("設定画面のヘルプ機能は現在開発中です。")
  }

  openNewCategoryModal() {
    this.categoryModalTitleTarget.textContent = "科目を追加"
    this.categoryFormTarget.action = this.categoriesPathValue
    this.categoryMethodFieldTarget.value = "post"
    this.categoryNameFieldTarget.value = ""
    this.categoryTypeFieldTarget.value = "expense"
    this.setSelectedIcon("fa-coins")
    this.openModal(this.categoryModalTarget)
  }

  openEditCategoryModal(event) {
    const { id, name, icon, defaultType } = event.currentTarget.dataset

    this.categoryModalTitleTarget.textContent = "科目を編集"
    this.categoryFormTarget.action = `${this.categoriesPathValue}/${id}`
    this.categoryMethodFieldTarget.value = "patch"
    this.categoryNameFieldTarget.value = name
    this.categoryTypeFieldTarget.value = defaultType
    this.setSelectedIcon(icon || "fa-coins")
    this.openModal(this.categoryModalTarget)
  }

  closeCategoryModal() {
    this.closeModal(this.categoryModalTarget)
  }

  selectIcon(event) {
    this.setSelectedIcon(event.currentTarget.dataset.icon)
  }

  setSelectedIcon(icon) {
    this.categoryIconFieldTarget.value = icon
    this.categoryIconPreviewTarget.className = `fa-solid ${icon}`

    this.iconOptionTargets.forEach((button) => {
      button.classList.toggle("border-kaikei-primary", button.dataset.icon === icon)
      button.classList.toggle("bg-kaikei-primary/10", button.dataset.icon === icon)
      button.classList.toggle("border-black/10", button.dataset.icon !== icon)
    })
  }

  openDeleteCategoryModal(event) {
    const { id } = event.currentTarget.dataset
    this.categoryDeleteFormTarget.action = `${this.categoriesPathValue}/${id}`
    this.openModal(this.deleteCategoryModalTarget)
  }

  closeDeleteCategoryModal() {
    this.closeModal(this.deleteCategoryModalTarget)
  }

  openModal(modal) {
    modal.classList.remove("hidden")
    modal.classList.add("flex")
  }

  closeModal(modal) {
    modal.classList.add("hidden")
    modal.classList.remove("flex")
  }
}
