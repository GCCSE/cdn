(function() {
  let dropzone;
  let counter = 0;
  let fileInput, form;
  let initialized = false;
  let uploading = false;

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  async function parseJson(response) {
    const text = await response.text();
    return text ? JSON.parse(text) : {};
  }

  async function uploadSelectedFile(file) {
    const directUploadUrl = form?.dataset.directUploadUrl;
    const completeUploadUrl = form?.dataset.completeUploadUrl;

    if (!directUploadUrl || !completeUploadUrl) {
      form.requestSubmit();
      return;
    }

    const prepareResponse = await fetch(directUploadUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({
        file: {
          filename: file.name,
          byte_size: file.size,
          content_type: file.type || "application/octet-stream"
        }
      })
    });

    const prepareJson = await parseJson(prepareResponse);
    if (!prepareResponse.ok) {
      throw new Error(prepareJson.error || "Could not prepare upload.");
    }

    const objectResponse = await fetch(prepareJson.upload_url, {
      method: "PUT",
      headers: prepareJson.headers || {},
      body: file
    });

    if (!objectResponse.ok) {
      throw new Error("Could not upload file to storage.");
    }

    const completeResponse = await fetch(completeUploadUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({ finalize_token: prepareJson.finalize_token })
    });

    const completeJson = await parseJson(completeResponse);
    if (!completeResponse.ok) {
      throw new Error(completeJson.error || "Could not finalize upload.");
    }

    window.location.assign("/uploads");
  }

  function init() {
    const formElement = document.querySelector("[data-dropzone-form]");
    if (!formElement) {
      fileInput = null;
      form = null;
      initialized = false;
      return;
    }

    if (initialized && form === formElement) return;

    form = formElement;
    fileInput = form.querySelector("[data-dropzone-input]");

    if (!fileInput) return;

    initialized = true;

    // Handle file input change
    fileInput.addEventListener("change", async (e) => {
      const file = e.target.files[0];
      if (!file || uploading) return;

      uploading = true;

      try {
        await uploadSelectedFile(file);
      } catch (error) {
        window.alert(error.message);
      } finally {
        uploading = false;
        fileInput.value = "";
      }
    });
  }

  // Prevent default drag behaviors
  document.addEventListener("dragover", (e) => {
    e.preventDefault();
  });

  // Show overlay when dragging enters window
  document.addEventListener("dragenter", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    if (counter === 0) {
      showDropzone();
    }
    counter++;
  });

  // Hide overlay when dragging leaves window
  document.addEventListener("dragleave", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    counter--;
    if (counter === 0) {
      hideDropzone();
    }
  });

  // Handle file drop
  document.addEventListener("drop", (e) => {
    if (!fileInput) return;
    e.preventDefault();
    counter = 0;
    hideDropzone();

    const files = e.dataTransfer.files;
    if (files.length > 0 && !uploading) {
      fileInput.files = files;
      fileInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
  });

  // Show full-screen dropzone overlay
  function showDropzone() {
    if (!dropzone) {
      dropzone = document.createElement("div");
      dropzone.classList.add("file-dropzone");

      const title = document.createElement("h1");
      title.innerText = "Drop your file here";
      dropzone.appendChild(title);

      document.body.appendChild(dropzone);
      document.body.style.overflow = "hidden";

      // Force reflow for transition
      void dropzone.offsetWidth;

      dropzone.classList.add("visible");
    }
  }

  // Hide full-screen dropzone overlay
  function hideDropzone() {
    if (dropzone) {
      dropzone.remove();
      dropzone = null;
      document.body.style.overflow = "auto";
      counter = 0;
    }
  }

  // Initialize on first load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Re-initialize on Turbo navigations
  document.addEventListener("turbo:load", init);
})();
