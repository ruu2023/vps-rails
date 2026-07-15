import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu" ]

  toggle() {
    this.open = !this.open
    this.render()
  }

  close() {
    this.open = false
    this.render()
  }

  closeIfOutside(event) {
    if (this.open && !this.element.contains(event.target)) this.close()
  }

  render() {
    this.menuTarget.classList.toggle("opacity-0", !this.open)
    this.menuTarget.classList.toggle("pointer-events-none", !this.open)
    this.menuTarget.classList.toggle("scale-95", !this.open)
  }
}
