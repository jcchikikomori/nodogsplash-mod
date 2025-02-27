var checkbox = document.querySelector('input[type="checkbox"]');
var elSubmit = document.querySelector('button[type="submit"]');
var macObj = { mac: '', manufacturer: 'Unspecified' };
var userName = document.getElementById('username');

if (!!elSubmit) {
  elSubmit.addEventListener('click', onclicksubmit);
}

if (!!userName) {
  userName.addEventListener('input', function () {
    forceLower(userName);
  });
}

function forceLower(strInput) {
  strInput.value = strInput.value.toLowerCase();
}

function onclicksubmit(event) {
  // Validations
  var checkedCount = checkbox ? document.querySelectorAll('input[type="checkbox"]:checked').length : 0;
  console.debug(checkedCount);
  if (checkedCount === 0) {
    alert('Please check if you agreed on Terms & Conditions');
    event.preventDefault(); // Prevent form submission
    return;
  }
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
      error: 'Invalid MAC address format',
      mac: mac.toUpperCase(),
    };
  }
}

function parseUserAgent(userAgent) {
  var deviceInfo = {
    manufacturer: "Unknown",
    device: "Unknown",
    browser: "Unknown"
  };

  // Regular expressions for common manufacturers and devices
  var regexes = [
    { regex: /Windows NT/i, manufacturer: "Microsoft", device: "Windows PC" },
    { regex: /Samsung|SM-/i, manufacturer: "Samsung", device: "Galaxy Phone" },
    { regex: /iPhone|iPod/i, manufacturer: "Apple", device: "iPhone" },
    { regex: /iPad/i, manufacturer: "Apple", device: "iPad Tablet" },
    { regex: /Huawei|HONOR/i, manufacturer: "Huawei", device: "Huawei/Honor Phone" },
    { regex: /Oppo|CPH|PCLM/i, manufacturer: "Oppo", device: "Oppo Phone" },
    { regex: /Vivo|V1/i, manufacturer: "Vivo", device: "Vivo Phone" },
    { regex: /Xiaomi|MI|Redmi|MIX|POCO|M2101K/i, manufacturer: "Xiaomi", device: "Xiaomi/Redmi Phone" },
  ];

  for (var i = 0; i < regexes.length; i++) {
    if (regexes[i].regex.test(userAgent)) {
      deviceInfo.manufacturer = regexes[i].manufacturer;
      if (regexes[i].device) {
        deviceInfo.device = regexes[i].device;
      }
      break;
    }
  }

  // Regular expressions for common browsers
  var browserRegexes = [
    { regex: /Chrome/i, browser: "Chrome" },
    { regex: /Firefox/i, browser: "Firefox" },
    { regex: /Safari/i, browser: "Safari" },
    { regex: /Edge/i, browser: "Edge" },
    { regex: /Opera/i, browser: "Opera" },
    { regex: /MSIE|Trident/i, browser: "Internet Explorer" }
  ];

  for (var j = 0; j < browserRegexes.length; j++) {
    if (browserRegexes[j].regex.test(userAgent)) {
      deviceInfo.browser = browserRegexes[j].browser;
      break;
    }
  }

  return deviceInfo;
}

document.addEventListener('DOMContentLoaded', () => {
  var _clientMac = document.getElementById("clientmac");
  var _clientMacAlt = document.getElementById("clientmac-alt");
  var _clientMacAltLi = document.getElementById("clientmac-alt-li");
  var _ouiElem = document.getElementById("oui");
  var _manufElem = document.getElementById("manufacturer");
  var _manufElemAlt = document.getElementById("brand");
  var _deviceElem = document.getElementById("device");
  var _deviceElemTerms = document.getElementById("terms-device");
  var _browserElem = document.getElementById("browser");
  var _clientMacVal = (!!_clientMac) ? _clientMac.getAttribute("value") : 'Unknown';

  parseMacAddress(_clientMacVal);
  console.log(macObj);

  if (_manufElem) _manufElem.innerHTML = macObj.manufacturer;
  if (!macObj.error && macObj.manufacturer !== 'Unspecified') {
    _ouiElem.hidden = false;
    _manufElem.hidden = false;
    if (!!_clientMacAltLi) _clientMacAltLi.hidden = false;
  } else {
    _ouiElem.hidden = true;
    _manufElem.hidden = true;
    if (!!_clientMacAltLi) _clientMacAltLi.hidden = true;
  }

  // Validate using user-agent from browser instead.
  var _userAgent = navigator.userAgent;
  console.debug(_userAgent);
  if (!!_userAgent) {
    var deviceInfo = parseUserAgent(_userAgent);
    console.log(deviceInfo);

    if (deviceInfo.manufacturer !== 'Unknown') {
      _manufElem.innerHTML = deviceInfo.manufacturer;
      _manufElemAlt.innerHTML = deviceInfo.manufacturer;
      if (deviceInfo.device !== 'Unknown') {
        _deviceElem.innerHTML = deviceInfo.device;
        if (!!_deviceElemTerms) _deviceElemTerms.innerHTML = deviceInfo.device;
      }
      _browserElem.innerHTML = deviceInfo.browser;
      _ouiElem.hidden = false;
      _manufElem.hidden = false;
      if (!!_clientMacAltLi) _clientMacAltLi.hidden = false;
    } else {
      _ouiElem.hidden = true;
      _manufElem.hidden = true;
      if (!!_clientMacAltLi) _clientMacAltLi.hidden = true;
    }
  }

  // Other views to validate
  if (!!_clientMacAlt && _clientMacAlt.innerHTML === '$clientmac') {
    _clientMacAltLi.hidden = true;
  }

  // Checkbox manual input (on agree)
  document.getElementById('accept-terms').addEventListener('click', function () {
    checkbox.checked = true;
  });
});