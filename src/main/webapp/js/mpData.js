/*******************************************************************************
* Copyright (c) 2018 IBM Corporation and others.
* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*
* Contributors:
*     IBM Corporation - initial API and implementation
*******************************************************************************/
function displayHostname() {
  getHostname();
}

function getHostname() {
  var url = location.href + "api/env";
  var req = new XMLHttpRequest();
  var hostnameValue = document.getElementById("hostnameValue");
  req.onreadystatechange = function () {
      if (req.readyState != 4) return; // Not there yet
      if (req.status != 200) {
          hostnameValue.innerHTML = "";
          return;
      }
      var resp = req.responseText;
      hostnameValue.innerHTML = "Running on virtual server instance: " + resp;
  };
  req.open("GET", url, true);
  req.send();
}

function displaySystemProperties() {
    getSystemPropertiesRequest();
}

function getSystemPropertiesRequest() {
    var propToDisplay = ["user.name", "os.name", "wlp.install.dir", "wlp.server.name" ];
    var url = location.href + "api/properties";
    var req = new XMLHttpRequest();
    var table = document.getElementById("systemPropertiesTable");
    // Create the callback:
    req.onreadystatechange = function () {
        if (req.readyState != 4) return; // Not there yet
        if (req.status != 200) {
            table.innerHTML = "";
            var row = document.createElement("tr");
            var th = document.createElement("th");
            th.innerText = req.statusText;
            row.appendChild(th);
            table.appendChild(row);

            addSourceRow(table, url);
            return;
        }
        // Request successful, read the response
        var resp = JSON.parse(req.responseText);
        for (var i = 0; i < propToDisplay.length; i++) {
            var key = propToDisplay[i];
            if (resp.hasOwnProperty(key)) {
                var row = document.createElement("tr");
                var keyData = document.createElement("td");
                keyData.innerText = key;
                var valueData = document.createElement("td");
                valueData.innerText = resp[key];
                row.appendChild(keyData);
                row.appendChild(valueData);
                table.appendChild(row);
            }
        }

        addSourceRow(table, url);
    };
    req.open("GET", url, true);
    req.send();
}

function toggle(e) {
    var callerElement;
    if (!e) {
        if (window.event) {
            e = window.event;
            callerElement = e.currentTarget;
        } else {
            callerElement = window.toggle.caller.arguments[0].currentTarget; // for firefox
        }
    }

    var classes = callerElement.parentElement.classList;
    var collapsed = classes.contains("collapsed");
    var caretImg = callerElement.getElementsByClassName("caret")[0];
    var caretImgSrc = caretImg.getAttribute("src");
    if (collapsed) { // expand the section
        classes.replace("collapsed", "expanded");
        caretImg.setAttribute("src", caretImgSrc.replace("down", "up"));
    } else { // collapse the section
        classes.replace("expanded", "collapsed");
        caretImg.setAttribute("src", caretImgSrc.replace("up", "down"));
    }
}

function addSourceRow(table, url) {
    var sourceRow = document.createElement("tr");
    sourceRow.classList.add("sourceRow");
    var sourceText = document.createElement("td");
    sourceText.setAttribute("colspan", "100%");
    sourceText.innerHTML = "API Source\: <a href='"+url+"'>"+url+"</a>";
    sourceRow.appendChild(sourceText);
    table.appendChild(sourceRow);
}