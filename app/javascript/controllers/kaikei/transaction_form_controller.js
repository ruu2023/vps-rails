import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "type"]

  syncType() {
    const selected = this.categoryTarget.selectedOptions[0]
    const defaultType = selected?.dataset.defaultType
    if (defaultType) {
      this.typeTarget.value = defaultType
    }
  }
}
