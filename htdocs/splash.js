var elSubmits = document.querySelectorAll('.button-submit');
var macObj = { mac: '', manufacturer: 'Unspecified' };

for (var i = 0, l = elSubmits.length; i < l; i++) {
  var elSubmit = elSubmits[i];
  elSubmit.addEventListener('click', onclicksubmit);
}

document.addEventListener('DOMContentLoaded', () => {
  function openModal($el) {
    $el.classList.add('is-active');
  }
  function closeModal($el) {
    $el.classList.remove('is-active');
  }
  function closeAllModals() {
    (document.querySelectorAll('.modal') || []).forEach(($modal) => {
      closeModal($modal);
    });
  }
  // TERMS & CONDITIONS
  (document.querySelectorAll('.modal-trigger-terms') || []).forEach(($trigger) => {
    const modal = $trigger.dataset.target;
    const $target = document.getElementById(modal);
    $trigger.addEventListener('click', () => {
      openModal($target);
    });
  });
  // CLOSE MODALS
  (document.querySelectorAll('.modal-background, .modal-close, .modal-close-button, .modal-card-head .delete, .modal-card-foot .button') || []).forEach(($close) => {
    const $target = $close.closest('.modal');
    $close.addEventListener('click', () => {
      closeModal($target);
    });
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === "Escape") {
      closeAllModals();
    }
  });
});

document.getElementById('username').addEventListener('keyup', function (_e) {
  forceLower(this);
});

function forceLower(strInput) {
  strInput.value = strInput.value.toLowerCase();
}

function onclicksubmit(event) {
  // Validations
  var checkboxes = document.querySelectorAll('input[type="checkbox"]');
  var checkedCount = Array.from(checkboxes).filter(input => input.checked).length;
  // console.log(checkedCount);
  if (checkedCount === 0) {
    alert('Please check if you agreed on Terms & Conditions');
    event.preventDefault(); // Prevent form submission
    return;
  }

  // Begin loading
  var elSubmit = event.currentTarget;
  var classList = elSubmit.classList;
  if (classList.contains('is-loading')) {
    return;
  }
  classList.add('is-loading');
  setTimeout(function () {
    classList.remove('is-loading');
  }, ~~(Math.random() * 8000));
}

function parseMacAddress(mac) {
  // Regular expression to match MAC address
  var macRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/;
  // Check if MAC address matches the pattern
  if (macRegex.test(mac)) {
    // Extract the first 6 characters (the OUI) to determine the manufacturer
    var oui = mac.split(/[:-]/).slice(0, 3).join(':').toUpperCase();
    // Manufacturer lookup (you can expand this as needed)
    var manufacturers = {
      '00:23:EB': 'Samsung',
      'F4:02:28': 'Samsung (Phone)',
      '00:0A:27': 'Apple',
    };
    // Check if manufacturer exists in the lookup table
    if (manufacturers[oui]) {
      macObj = {
        mac: mac.toUpperCase(),
        manufacturer: manufacturers[oui]
      };
    } else {
      macObj = {
        mac: mac.toUpperCase(),
        manufacturer: 'Unspecified'
      };
    }
  } else {
    macObj = {
      error: 'Invalid MAC address format'
    };
  }
}
window.onload = function () {
  var _clientMac = document.getElementById("clientmac");
  var _ouiElem = document.getElementById("oui");
  var _manufElem = document.getElementById("manufacturer");
  var _clientMacVal = _clientMac.getAttribute("value");
  parseMacAddress(_clientMacVal);
  console.log(macObj);
  if (_manufElem) _manufElem.innerHTML = macObj.manufacturer;
  if (!macObj.error && macObj.manufacturer !== 'Unspecified') {
    _ouiElem.hidden = false;
    _manufElem.hidden = false;
  } else {
    _ouiElem.hidden = true;
    _manufElem.hidden = true;
  }
};