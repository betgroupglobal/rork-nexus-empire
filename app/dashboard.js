const state = {
  subjects: [],
  comms: [],
  emails: [],
  alerts: [],
  dashboard: null,
};

const tabs = {
  warroom: document.getElementById("panel-warroom"),
  subjects: document.getElementById("panel-subjects"),
  comms: document.getElementById("panel-comms"),
  email: document.getElementById("panel-email"),
  alerts: document.getElementById("panel-alerts"),
};

const titleMap = {
  warroom: "War Room",
  subjects: "Subjects",
  comms: "Comms",
  email: "Email",
  alerts: "Alerts",
};

function setStatus(text, mode = "") {
  const el = document.getElementById("server-status");
  el.textContent = text;
  el.className = `status-pill ${mode}`.trim();
}

function trpcInput(input) {
  return encodeURIComponent(JSON.stringify({ json: input }));
}

async function trpcQuery(procedure, input) {
  const url = input
    ? `/api/trpc/${procedure}?input=${trpcInput(input)}`
    : `/api/trpc/${procedure}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${procedure} failed`);
  const payload = await res.json();
  return payload.result.data.json;
}

function selectTab(key) {
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === key);
  });
  Object.entries(tabs).forEach(([k, panel]) => {
    panel.classList.toggle("active", k === key);
  });
  document.getElementById("tab-title").textContent = titleMap[key];
}

function renderWarRoom() {
  const stats = document.getElementById("warroom-stats");
  const d = state.dashboard;
  const list = [
    ["Current Applications", d?.currentApplicationsTotal ?? 0],
    ["Total Subjects", d?.totalCount ?? state.subjects.length],
    ["Unread Comms", d?.unreadComms ?? 0],
    ["Unread Emails", d?.unreadEmails ?? 0],
    ["Urgent Actions", d?.urgentCount ?? 0],
  ];
  stats.innerHTML = list
    .map(
      ([label, value]) =>
        `<div class="stat"><div class="label">${label}</div><div class="value">${value}</div></div>`
    )
    .join("");

  const longest = document.getElementById("longest-active");
  if (d?.longestActive) {
    longest.innerHTML = `<div class="row-head"><span>Longest Active</span><span class="badge warn">${d.longestActive.bank}</span></div><div class="row-meta">${d.longestActive.subjectName} · Submitted ${new Date(d.longestActive.submittedDate).toLocaleDateString()}</div>`;
  } else {
    longest.innerHTML = `<div class="row-meta">No active application data yet.</div>`;
  }
}

function renderList(containerId, rows, mapper) {
  const el = document.getElementById(containerId);
  el.innerHTML = rows.map(mapper).join("");
}

function renderAll() {
  renderWarRoom();

  renderList("subjects-list", state.subjects, (s) => {
    const statusClass = s.status === "At Risk" ? "critical" : s.status === "Pending" ? "warn" : "";
    return `<div class="row"><div class="row-head"><span>${s.name}</span><span class="badge ${statusClass}">${s.status}</span></div><div class="row-meta">Score ${s.healthScore} · ${s.type} · ${s.assignedEmail}</div></div>`;
  });

  renderList("comms-list", state.comms, (c) => {
    return `<div class="row"><div class="row-head"><span>${c.sender}</span><span class="badge">${c.type}</span></div><div class="row-meta">${c.entityName} · ${c.content}</div></div>`;
  });

  renderList("emails-list", state.emails, (e) => {
    const b = e.isFlagged ? "warn" : "";
    return `<div class="row"><div class="row-head"><span>${e.subject}</span><span class="badge ${b}">${e.category}</span></div><div class="row-meta">${e.entityName} · ${e.sender}</div></div>`;
  });

  renderList("alerts-list", state.alerts, (a) => {
    const p = a.priority === "Critical" ? "critical" : a.priority === "Warning" ? "warn" : "";
    return `<div class="row"><div class="row-head"><span>${a.title}</span><span class="badge ${p}">${a.priority}</span></div><div class="row-meta">${a.entityName ?? "Global"} · ${a.message}</div></div>`;
  });
}

async function boot() {
  setStatus("Connecting");
  try {
    const [dashboard, subjects, comms, emails, alerts] = await Promise.all([
      trpcQuery("entities.dashboard"),
      trpcQuery("entities.list"),
      trpcQuery("communications.list"),
      trpcQuery("emails.list"),
      trpcQuery("alerts.list"),
    ]);

    state.dashboard = dashboard;
    state.subjects = subjects;
    state.comms = comms;
    state.emails = emails;
    state.alerts = alerts;
    renderAll();
    setStatus("Live", "ok");
  } catch (err) {
    setStatus("Offline", "bad");
    document.getElementById("warroom-stats").innerHTML = `<div class="row-meta">${String(err)}</div>`;
  }
}

document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => selectTab(btn.dataset.tab));
});

selectTab("warroom");
boot();
