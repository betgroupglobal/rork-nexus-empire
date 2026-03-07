const state = {
  subjects: [],
  comms: [],
  emails: [],
  alerts: [],
  dashboard: null,
  authUser: null,
  token: localStorage.getItem("nexus_token") || "",
  filters: {
    subjects: { search: "", status: "" },
    comms: { subjectId: "", type: "" },
    emails: { subjectId: "", category: "" },
    alerts: { type: "" },
  },
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

function setAuthMessage(text) {
  document.getElementById("auth-message").textContent = text;
}

function setAuthUser(user) {
  state.authUser = user;
  const el = document.getElementById("auth-status");
  if (user) {
    el.textContent = user.email;
    el.className = "status-pill ok";
  } else {
    el.textContent = "Guest";
    el.className = "status-pill";
  }
}

function trpcInput(input) {
  return encodeURIComponent(JSON.stringify({ json: input }));
}

function extractTRPCJson(payload) {
  return payload?.result?.data?.json;
}

async function trpcQuery(procedure, input) {
  const url = input
    ? `/api/trpc/${procedure}?input=${trpcInput(input)}`
    : `/api/trpc/${procedure}`;
  const headers = {};
  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }
  const res = await fetch(url, { headers });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok || payload.error) {
    const message = payload?.error?.message || `${procedure} failed`;
    throw new Error(message);
  }
  return extractTRPCJson(payload);
}

async function trpcMutation(procedure, input) {
  const headers = { "Content-Type": "application/json" };
  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }
  const res = await fetch(`/api/trpc/${procedure}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ json: input ?? null }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok || payload.error) {
    const message = payload?.error?.message || `${procedure} failed`;
    throw new Error(message);
  }
  return extractTRPCJson(payload);
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

function makeBadgeClass(base, value) {
  if (value === "Critical" || value === "At Risk") return `${base} critical`;
  if (value === "Warning" || value === "Pending" || value === "Stalled") return `${base} warn`;
  return base;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
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
    ["Total Firepower", Math.round(d?.totalFirepower ?? 0)],
    ["Monthly Burn", Math.round(d?.monthlyBurn ?? 0)],
  ];
  stats.innerHTML = list
    .map(
      ([label, value]) =>
        `<div class="stat"><div class="label">${label}</div><div class="value">${value}</div></div>`
    )
    .join("");

  const longest = document.getElementById("longest-active");
  if (d?.longestActive) {
    longest.innerHTML = `<div class="row-head"><span>Longest Active</span><span class="badge warn">${escapeHtml(d.longestActive.bank)}</span></div><div class="row-meta">${escapeHtml(d.longestActive.subjectName)} · Submitted ${new Date(d.longestActive.submittedDate).toLocaleDateString()}</div>`;
  } else {
    longest.innerHTML = `<div class="row-meta">No active application data yet.</div>`;
  }
}

function renderSubjectOptions() {
  const options = [`<option value="">All subjects</option>`]
    .concat(
      state.subjects.map(
        (s) => `<option value="${s.id}">${escapeHtml(s.name)}</option>`
      )
    )
    .join("");

  ["comm-subject", "comms-filter-subject", "emails-filter-subject"].forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;
    const current = el.value;
    el.innerHTML = id === "comm-subject" ? options.replace("All subjects", "Select subject") : options;
    if (current && state.subjects.some((s) => s.id === current)) {
      el.value = current;
    }
  });
}

function getFilteredSubjects() {
  return state.subjects.filter((s) => {
    const search = state.filters.subjects.search.toLowerCase();
    const searchOk =
      !search ||
      s.name.toLowerCase().includes(search) ||
      s.assignedEmail.toLowerCase().includes(search) ||
      s.assignedPhone.toLowerCase().includes(search);
    const statusOk = !state.filters.subjects.status || s.status === state.filters.subjects.status;
    return searchOk && statusOk;
  });
}

function renderSubjects() {
  const rows = getFilteredSubjects()
    .map((s) => {
      const badgeClass = makeBadgeClass("badge", s.status);
      const checked = s.isFlagged ? "checked" : "";
      return `<div class="row"><div class="row-head"><span>${escapeHtml(s.name)}</span><span class="${badgeClass}">${escapeHtml(s.status)}</span></div><div class="row-meta">Score ${s.healthScore} · ${escapeHtml(s.type)} · ${escapeHtml(s.assignedEmail)} · ${escapeHtml(s.assignedPhone)}</div><div class="row-actions"><button class="btn ghost" data-action="subject-edit" data-id="${s.id}" type="button">Update</button><button class="btn ghost" data-action="subject-flag" data-id="${s.id}" type="button">${checked ? "Unflag" : "Flag"}</button><button class="btn danger" data-action="subject-archive" data-id="${s.id}" type="button">Archive</button></div></div>`;
    })
    .join("");

  document.getElementById("subjects-list").innerHTML = rows || `<div class="row-meta">No subjects found.</div>`;
}

function renderComms() {
  const rows = state.comms
    .map((c) => {
      const unread = c.isRead ? "" : "warn";
      const readAction = c.isRead
        ? ""
        : `<button class="btn ghost" data-action="comm-mark-read" data-id="${c.id}" type="button">Mark Read</button>`;
      return `<div class="row"><div class="row-head"><span>${escapeHtml(c.sender)}</span><span class="badge ${unread}">${escapeHtml(c.type)}</span></div><div class="row-meta">${escapeHtml(c.entityName)} · ${escapeHtml(c.content)}</div><div class="row-meta">${new Date(c.timestamp).toLocaleString()}</div><div class="row-actions">${readAction}</div></div>`;
    })
    .join("");

  document.getElementById("comms-list").innerHTML = rows || `<div class="row-meta">No communications found.</div>`;
}

function renderEmails() {
  const rows = state.emails
    .map((e) => {
      const badgeClass = e.isFlagged ? "badge warn" : "badge";
      const readAction = e.isRead
        ? ""
        : `<button class="btn ghost" data-action="email-mark-read" data-id="${e.id}" type="button">Mark Read</button>`;
      return `<div class="row"><div class="row-head"><span>${escapeHtml(e.subject)}</span><span class="${badgeClass}">${escapeHtml(e.category)}</span></div><div class="row-meta">${escapeHtml(e.entityName)} · ${escapeHtml(e.senderAddress)}</div><div class="row-meta">${escapeHtml(e.snippet)}</div><div class="row-actions">${readAction}<button class="btn ghost" data-action="email-toggle-flag" data-id="${e.id}" type="button">${e.isFlagged ? "Unflag" : "Flag"}</button></div></div>`;
    })
    .join("");

  document.getElementById("emails-list").innerHTML = rows || `<div class="row-meta">No emails found.</div>`;
}

function renderAlerts() {
  const rows = state.alerts
    .map((a) => {
      const badgeClass = makeBadgeClass("badge", a.priority);
      const readAction = a.isRead
        ? ""
        : `<button class="btn ghost" data-action="alert-mark-read" data-id="${a.id}" type="button">Mark Read</button>`;
      return `<div class="row"><div class="row-head"><span>${escapeHtml(a.title)}</span><span class="${badgeClass}">${escapeHtml(a.priority)}</span></div><div class="row-meta">${escapeHtml(a.entityName ?? "Global")} · ${escapeHtml(a.type)}</div><div class="row-meta">${escapeHtml(a.message)}</div><div class="row-actions">${readAction}</div></div>`;
    })
    .join("");

  document.getElementById("alerts-list").innerHTML = rows || `<div class="row-meta">No alerts found.</div>`;
}

function renderAll() {
  renderWarRoom();
  renderSubjectOptions();
  renderSubjects();
  renderComms();
  renderEmails();
  renderAlerts();
}

function parseNumber(value) {
  if (value === "" || value == null) return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}

async function loadDashboard() {
  state.dashboard = await trpcQuery("entities.dashboard");
}

async function loadSubjects() {
  state.subjects = await trpcQuery("entities.list");
}

async function loadComms() {
  const input = {};
  if (state.filters.comms.subjectId) input.subjectId = state.filters.comms.subjectId;
  if (state.filters.comms.type) input.type = state.filters.comms.type;
  state.comms = await trpcQuery("communications.list", Object.keys(input).length ? input : undefined);
}

async function loadEmails() {
  const input = {};
  if (state.filters.emails.subjectId) input.subjectId = state.filters.emails.subjectId;
  if (state.filters.emails.category) input.category = state.filters.emails.category;
  state.emails = await trpcQuery("emails.list", Object.keys(input).length ? input : undefined);
}

async function loadAlerts() {
  const input = state.filters.alerts.type ? { type: state.filters.alerts.type } : undefined;
  state.alerts = await trpcQuery("alerts.list", input);
}

async function loadAllData() {
  await Promise.all([loadDashboard(), loadSubjects(), loadComms(), loadEmails(), loadAlerts()]);
  renderAll();
}

async function refreshAll() {
  setStatus("Syncing");
  try {
    await loadAllData();
    setStatus("Live", "ok");
  } catch (err) {
    setStatus("Offline", "bad");
    setAuthMessage(String(err));
  }
}

async function refreshAuthUser() {
  if (!state.token) {
    setAuthUser(null);
    return;
  }
  try {
    const me = await trpcQuery("auth.me");
    setAuthUser(me);
  } catch {
    state.token = "";
    localStorage.removeItem("nexus_token");
    setAuthUser(null);
  }
}

async function handleLoginSubmit(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  try {
    const payload = await trpcMutation("auth.login", {
      email: String(formData.get("email") || ""),
      password: String(formData.get("password") || ""),
    });
    state.token = payload.token;
    localStorage.setItem("nexus_token", payload.token);
    setAuthUser(payload.user);
    setAuthMessage(`Logged in as ${payload.user.email}`);
    form.reset();
  } catch (err) {
    setAuthMessage(String(err));
  }
}

async function handleRegisterSubmit(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  try {
    const payload = await trpcMutation("auth.register", {
      name: String(formData.get("name") || ""),
      email: String(formData.get("email") || ""),
      password: String(formData.get("password") || ""),
    });
    state.token = payload.token;
    localStorage.setItem("nexus_token", payload.token);
    setAuthUser(payload.user);
    setAuthMessage(`Registered ${payload.user.email}`);
    form.reset();
  } catch (err) {
    setAuthMessage(String(err));
  }
}

async function handleCreateSubject(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  try {
    await trpcMutation("entities.create", {
      name: String(formData.get("name") || ""),
      type: String(formData.get("type") || "Person"),
      creditLimit: Number(formData.get("creditLimit") || 0),
      assignedPhone: String(formData.get("assignedPhone") || ""),
      assignedEmail: String(formData.get("assignedEmail") || ""),
      notes: String(formData.get("notes") || ""),
    });
    form.reset();
    await refreshAll();
  } catch (err) {
    setAuthMessage(String(err));
  }
}

async function updateSubjectPrompt(id) {
  const subject = state.subjects.find((s) => s.id === id);
  if (!subject) return;

  const name = prompt("Name", subject.name) ?? subject.name;
  const status = prompt("Status (Active|Pending|Dormant|At Risk|Archived)", subject.status) ?? subject.status;
  const healthScore = prompt("Health Score", String(subject.healthScore)) ?? String(subject.healthScore);
  const creditLimit = prompt("Credit Limit", String(subject.creditLimit)) ?? String(subject.creditLimit);
  const monthlyBurn = prompt("Monthly Burn", String(subject.monthlyBurn)) ?? String(subject.monthlyBurn);
  const notes = prompt("Notes", subject.notes) ?? subject.notes;

  const payload = {
    id,
    name,
    status,
    healthScore: parseNumber(healthScore),
    creditLimit: parseNumber(creditLimit),
    monthlyBurn: parseNumber(monthlyBurn),
    notes,
  };

  await trpcMutation("entities.update", payload);
  await refreshAll();
}

async function handleCreateComm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  const subjectId = String(formData.get("subjectId") || "");
  const subject = state.subjects.find((s) => s.id === subjectId);
  if (!subject) {
    setAuthMessage("Please select a subject for communication creation");
    return;
  }

  try {
    await trpcMutation("communications.create", {
      subjectId,
      subjectName: subject.name,
      type: String(formData.get("type") || "SMS"),
      sender: String(formData.get("sender") || ""),
      content: String(formData.get("content") || ""),
      phoneNumber: String(formData.get("phoneNumber") || ""),
      duration: parseNumber(String(formData.get("duration") || "")) ?? null,
      transcription: String(formData.get("transcription") || "") || null,
    });
    form.reset();
    await refreshAll();
  } catch (err) {
    setAuthMessage(String(err));
  }
}

async function handleRootClick(event) {
  const target = event.target;
  if (!(target instanceof HTMLElement)) return;
  const action = target.dataset.action;
  const id = target.dataset.id;
  if (!action || !id) return;

  try {
    if (action === "subject-flag") {
      await trpcMutation("entities.toggleFlag", { id });
      await refreshAll();
      return;
    }
    if (action === "subject-archive") {
      await trpcMutation("entities.archive", { id });
      await refreshAll();
      return;
    }
    if (action === "subject-edit") {
      await updateSubjectPrompt(id);
      return;
    }
    if (action === "comm-mark-read") {
      await trpcMutation("communications.markRead", { id });
      await refreshAll();
      return;
    }
    if (action === "email-mark-read") {
      await trpcMutation("emails.markRead", { id });
      await refreshAll();
      return;
    }
    if (action === "email-toggle-flag") {
      await trpcMutation("emails.toggleFlag", { id });
      await refreshAll();
      return;
    }
    if (action === "alert-mark-read") {
      await trpcMutation("alerts.markRead", { id });
      await refreshAll();
    }
  } catch (err) {
    setAuthMessage(String(err));
  }
}

function attachEventHandlers() {
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => selectTab(btn.dataset.tab));
  });

  document.getElementById("login-form").addEventListener("submit", handleLoginSubmit);
  document.getElementById("register-form").addEventListener("submit", handleRegisterSubmit);
  document.getElementById("subject-create-form").addEventListener("submit", handleCreateSubject);
  document.getElementById("comm-create-form").addEventListener("submit", handleCreateComm);

  document.getElementById("btn-refresh-all").addEventListener("click", refreshAll);
  document.getElementById("btn-me").addEventListener("click", async () => {
    try {
      const me = await trpcQuery("auth.me");
      setAuthUser(me);
      setAuthMessage(`Current user ${me.email}`);
    } catch (err) {
      setAuthMessage(String(err));
    }
  });

  document.getElementById("btn-logout").addEventListener("click", () => {
    state.token = "";
    localStorage.removeItem("nexus_token");
    setAuthUser(null);
    setAuthMessage("Logged out");
  });

  document.getElementById("subjects-filter-apply").addEventListener("click", () => {
    state.filters.subjects.search = String(document.getElementById("subjects-search").value || "");
    state.filters.subjects.status = String(document.getElementById("subjects-status").value || "");
    renderSubjects();
  });

  document.getElementById("comms-filter-apply").addEventListener("click", async () => {
    state.filters.comms.subjectId = String(document.getElementById("comms-filter-subject").value || "");
    state.filters.comms.type = String(document.getElementById("comms-filter-type").value || "");
    await loadComms();
    renderComms();
  });

  document.getElementById("emails-filter-apply").addEventListener("click", async () => {
    state.filters.emails.subjectId = String(document.getElementById("emails-filter-subject").value || "");
    state.filters.emails.category = String(document.getElementById("emails-filter-category").value || "");
    await loadEmails();
    renderEmails();
  });

  document.getElementById("alerts-filter-apply").addEventListener("click", async () => {
    state.filters.alerts.type = String(document.getElementById("alerts-filter-type").value || "");
    await loadAlerts();
    renderAlerts();
  });

  document.getElementById("alerts-mark-all").addEventListener("click", async () => {
    try {
      await trpcMutation("alerts.markAllRead", null);
      await refreshAll();
    } catch (err) {
      setAuthMessage(String(err));
    }
  });

  document.body.addEventListener("click", handleRootClick);
}

async function boot() {
  selectTab("warroom");
  attachEventHandlers();
  await refreshAuthUser();
  await refreshAll();
}

boot();
