/**
 * Bindocsis LiveView JavaScript Hooks
 * 
 * These hooks are automatically loaded when using the embedded UI
 * via the `bindocsis_live` router macro.
 * 
 * Host applications should include this in their app.js:
 * 
 *   import { BindocsisHooks } from "bindocsis"
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: { ...BindocsisHooks }
 *   })
 */

export const BindocsisHooks = {
  /**
   * Download hook - handles file downloads from LiveView push_event
   * 
   * Usage in LiveView:
   *   push_event(socket, "download", %{
   *     content: Base.encode64(content),
   *     filename: "file.bin",
   *     binary: true
   *   })
   */
  Download: {
    mounted() {
      this.handleEvent("download", ({ content, filename, binary }) => {
        // Decode base64 content
        const decoded = binary ? atob(content) : content;
        
        // Convert to blob
        let blob;
        if (binary) {
          const bytes = new Uint8Array(decoded.length);
          for (let i = 0; i < decoded.length; i++) {
            bytes[i] = decoded.charCodeAt(i);
          }
          blob = new Blob([bytes], { type: "application/octet-stream" });
        } else {
          blob = new Blob([decoded], { type: "text/plain" });
        }

        // Create download link and trigger
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      });
    }
  },

  /**
   * Clipboard hook - copies text to clipboard
   * 
   * Usage:
   *   <button phx-hook="Clipboard" data-copy="text to copy">Copy</button>
   */
  Clipboard: {
    mounted() {
      this.el.addEventListener("click", () => {
        const text = this.el.dataset.copy;
        navigator.clipboard.writeText(text).then(() => {
          // Show feedback
          const original = this.el.innerHTML;
          this.el.innerHTML = "Copied!";
          setTimeout(() => {
            this.el.innerHTML = original;
          }, 1500);
        });
      });
    }
  },

  /**
   * AutoFocus hook - focuses an element on mount
   * 
   * Usage:
   *   <input phx-hook="AutoFocus" />
   */
  AutoFocus: {
    mounted() {
      this.el.focus();
      // Move cursor to end if it's an input
      if (this.el.setSelectionRange) {
        const len = this.el.value.length;
        this.el.setSelectionRange(len, len);
      }
    }
  },

  /**
   * DropZone hook - enhanced drag and drop file upload
   * 
   * Usage:
   *   <div phx-hook="DropZone" phx-drop-target={@uploads.config.ref}>
   */
  DropZone: {
    mounted() {
      this.el.addEventListener("dragover", (e) => {
        e.preventDefault();
        this.el.classList.add("border-blue-500", "bg-blue-900/20");
      });

      this.el.addEventListener("dragleave", (e) => {
        e.preventDefault();
        this.el.classList.remove("border-blue-500", "bg-blue-900/20");
      });

      this.el.addEventListener("drop", (e) => {
        this.el.classList.remove("border-blue-500", "bg-blue-900/20");
      });
    }
  },

  /**
   * SortableList hook - drag and drop reordering
   * 
   * Requires Sortable.js to be loaded separately.
   * 
   * Usage:
   *   <div phx-hook="SortableList" phx-value-group="tlvs">
   */
  SortableList: {
    mounted() {
      if (typeof Sortable === "undefined") {
        console.warn("SortableList hook requires Sortable.js");
        return;
      }

      const group = this.el.dataset.sortGroup || "items";
      
      new Sortable(this.el, {
        animation: 150,
        ghostClass: "opacity-50",
        handle: "[data-drag-handle]",
        onEnd: (evt) => {
          this.pushEvent("reorder", {
            group: group,
            from: evt.oldIndex,
            to: evt.newIndex
          });
        }
      });
    }
  },

  /**
   * HexViewer hook - interactive hex dump with highlighting
   */
  HexViewer: {
    mounted() {
      this.el.addEventListener("mouseover", (e) => {
        if (e.target.dataset.offset) {
          const offset = parseInt(e.target.dataset.offset);
          // Highlight corresponding bytes
          this.el.querySelectorAll(`[data-offset="${offset}"]`).forEach(el => {
            el.classList.add("bg-blue-900");
          });
        }
      });

      this.el.addEventListener("mouseout", (e) => {
        if (e.target.dataset.offset) {
          const offset = parseInt(e.target.dataset.offset);
          this.el.querySelectorAll(`[data-offset="${offset}"]`).forEach(el => {
            el.classList.remove("bg-blue-900");
          });
        }
      });
    }
  },

  /**
   * Tooltip hook - shows tooltips on hover
   * 
   * Usage:
   *   <span phx-hook="Tooltip" data-tip="Tooltip text">Hover me</span>
   */
  Tooltip: {
    mounted() {
      const tip = this.el.dataset.tip;
      if (!tip) return;

      const tooltip = document.createElement("div");
      tooltip.className = "absolute z-50 px-2 py-1 text-xs bg-gray-700 text-gray-100 rounded shadow-lg whitespace-nowrap opacity-0 transition-opacity pointer-events-none";
      tooltip.textContent = tip;
      document.body.appendChild(tooltip);

      this.el.addEventListener("mouseenter", () => {
        const rect = this.el.getBoundingClientRect();
        tooltip.style.left = `${rect.left + rect.width / 2 - tooltip.offsetWidth / 2}px`;
        tooltip.style.top = `${rect.top - tooltip.offsetHeight - 5}px`;
        tooltip.classList.remove("opacity-0");
      });

      this.el.addEventListener("mouseleave", () => {
        tooltip.classList.add("opacity-0");
      });

      this.tooltip = tooltip;
    },

    destroyed() {
      if (this.tooltip) {
        this.tooltip.remove();
      }
    }
  }
};

// Default export for easy importing
export default BindocsisHooks;
