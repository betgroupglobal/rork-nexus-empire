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

const tabConfig = {
  warroom: {
    title: "War Room",
    subtitle: "Overview of live health, credentials, pressure points and next action.",
  },
  subjects: {
    title: "Subjects",
    subtitle: "Create, refine and work through the subject roster with a lighter record desk.",
  },
  comms: {
    title: "Comms",
    subtitle: "Capture calls and messages, then clear unread contact pressure quickly.",
  },
  email: {
    title: "Email",
    subtitle: "Review the mailbox with stronger focus on flagged and valuable signal.",
  },
  alerts: {
    title: "Alerts",
    subtitle: "Keep urgency precise, easy to scan and fast to clear.",
  },
};

function setStatus(text, mode = "warn") {
  const element = document.getElementById("server-status");
  element.textContent = text;
  element.className = `pill pill-${mode}`;
}

function setAuthMessage(text) {
  document.getElementById("auth-message").textContent = text;
}

function setAuthUser(user) {
  state.authUser = user;
  const element = document.getElementById("auth-status");
  if (user) {
    element.textContent = user.email;
    element.className = "pill pill-ok";
    return;
  }
  element.textContent = "Guest";
  element.className = "pill";
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
  const response = await fetch(url, { headers });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.error) {
    throw new Error(payload?.error?.message || `${procedure} failed`);
  }
  return extractTRPCJson(payload);
}

async function trpcMutation(procedure, input) {
  const headers = { "Content-Type": "application/json" };
  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }
  const response = await fetch(`/api/trpc/${procedure}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ json: input ?? null }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.error) {
    throw new Error(payload?.error?.message || `${procedure} failed`);
  }
  return extractTRPCJson(payload);
}

function selectTab(key) {
  document.querySelectorAll(".tab-btn").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === key);
  });
  Object.entries(tabs).forEach(([tabKey, panel]) => {
    panel.classList.toggle("active", tabKey === key);
  });
  document.getElementById("tab-title").textContent = tabConfig[key].title;
  document.getElementById("tab-subtitle").textContent = tabConfig[key].subtitle;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function emptyState(text) {
  return `<div class="empty-state">${escapeHtml(text)}</div>`;
}

function formatCurrency(value) {
  return new Intl.NumberFormat("en-AU", {
    style: "currency",
    currency: "AUD",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

function formatCompact(value) {
  return new Intl.NumberFormat("en-AU", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(Number(value || 0));
}

function relativeTime(value) {
  const timestamp = new Date(value).getTime();
  if (Number.isNaN(timestamp)) return "Unknown";
  const diffMinutes = Math.round((Date.now() - timestamp) / 60000);
  if (diffMinutes < 1) return "Just now";
  if (diffMinutes < 60) return `${diffMinutes} min ago`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours} hr ago`;
  const diffDays = Math.round(diffHours / 24);
  return `${diffDays} day ago`;
}

function makeBadgeClass(base, value) {
  if (value === "Critical" || value === "At Risk") return `${base} critical`;
  if (value === "Warning" || value === "Pending" || value === "Stalled") return `${base} warn`;
  if (value === "Info" || value === "Active" || value === "Approved") return `${base} success`;
  return base;
}

function scoreClass(score) {
  if (score >= 85) return "score-chip success";
  if (score >= 65) return "score-chip";
  if (score >= 45) return "score-chip warn";
  return "score-chip critical";
}

function updateNavCounts() {
  document.getElementById("nav-warroom-count").textContent = String(
    state.dashboard?.urgentCount ?? 0
  );
  document.getElementById("nav-subjects-count").textContent = String(state.subjects.length);
  document.getElementById("nav-comms-count").textContent = String(
    state.comms.filter((item) => !item.isRead).length
  );
  document.getElementById("nav-email-count").textContent = String(
    state.emails.filter((item) => !item.isRead).length
  );
  document.getElementById("nav-alerts-count").textContent = String(
    state.alerts.filter((item) => !item.isRead).length
  );
}

function renderMetricCards() {
  const dashboard = state.dashboard;
  const totalSubjects = dashboard?.totalCount ?? state.subjects.length;
  const cards = [
    ["Current applications", dashboard?.currentApplicationsTotal ?? 0, false],
    ["Total subjects", totalSubjects, false],
    ["Unread comms", dashboard?.unreadComms ?? 0, false],
    ["Unread emails", dashboard?.unreadEmails ?? 0, false],
    ["Urgent actions", dashboard?.urgentCount ?? 0, false],
    ["Total firepower", formatCompact(dashboard?.totalFirepower ?? 0), true],
    ["Monthly burn", formatCurrency(dashboard?.monthlyBurn ?? 0), false],
  ];

  document.getElementById("warroom-stats").innerHTML = cards
    .map(([label, value, isPower]) => {
      const valueClass = isPower ? "metric-value power" : "metric-value";
      return `<div class="metric-card"><div class="metric-title">${escapeHtml(label)}</div><div class="${valueClass}">${escapeHtml(value)}</div></div>`;
    })
    .join("");
}

function renderPowerState() {
  const dashboard = state.dashboard;
  const totalSubjects = dashboard?.totalCount ?? state.subjects.length;
  const activeSubjects = dashboard?.activeCount ?? 0;
  const power = totalSubjects > 0 ? Math.round((activeSubjects / totalSubjects) * 100) : 0;
  const heroValue = document.getElementById("hero-power-value");
  heroValue.textContent = `${power}%`;
  heroValue.className = `hero-power-value ${power >= 75 ? "rating-high" : "rating-neutral"}`;
  document.getElementById("hero-power-sub").textContent = `${activeSubjects} active of ${totalSubjects} subjects`;
}

function renderPriorityQueue() {
  const dashboard = state.dashboard;
  const items = [];
  if ((dashboard?.urgentCount ?? 0) > 0) {
    items.push({
      title: `${dashboard.urgentCount} urgent alert${dashboard.urgentCount === 1 ? "" : "s"}`,
      note: "Critical queue items should be cleared first.",
      badge: "Critical",
    });
  }
  if ((dashboard?.unreadEmails ?? 0) > 0) {
    items.push({
      title: `${dashboard.unreadEmails} unread email${dashboard.unreadEmails === 1 ? "" : "s"}`,
      note: "Unread and flagged mail is ready for triage.",
      badge: "Email",
    });
  }
  if ((dashboard?.unreadComms ?? 0) > 0) {
    items.push({
      title: `${dashboard.unreadComms} unread communication${dashboard.unreadComms === 1 ? "" : "s"}`,
      note: "Calls, SMS and voicemail need acknowledgement.",
      badge: "Comms",
    });
  }
  if ((dashboard?.currentApplicationsTotal ?? 0) > 0) {
    items.push({
      title: `${dashboard.currentApplicationsTotal} application${dashboard.currentApplicationsTotal === 1 ? "" : "s"} in motion`,
      note: "Keep submitted and in-review records moving.",
      badge: "Pipeline",
    });
  }

  document.getElementById("priority-queue").innerHTML = items.length
    ? items
        .map((item) => {
          const badgeClass =
            item.badge === "Critical"
              ? "badge critical"
              : item.badge === "Pipeline"
                ? "badge success"
                : "badge";
          return `<div class="queue-item"><div class="queue-top"><div class="record-title">${escapeHtml(item.title)}</div><span class="${badgeClass}">${escapeHtml(item.badge)}</span></div><div class="meta">${escapeHtml(item.note)}</div></div>`;
        })
        .join("")
    : emptyState("No immediate pressure points right now.");
}

function renderSpotlight() {
  const dashboard = state.dashboard;
  const target = document.getElementById("longest-active");
  if (!dashboard?.longestActive) {
    target.innerHTML = emptyState("No active application data yet.");
    return;
  }
  target.innerHTML = `<div class="spotlight-surface"><div class="queue-top"><div class="record-title">${escapeHtml(dashboard.longestActive.subjectName)}</div><span class="badge warn">${escapeHtml(dashboard.longestActive.bank)}</span></div><div class="meta">Submitted ${new Date(dashboard.longestActive.submittedDate).toLocaleDateString()}</div><div class="meta">This record has been active longest and should be checked for the next unblocker.</div></div>`;
}

function renderActivity() {
  const rows = state.alerts
    .slice(0, 6)
    .map((alert) => {
      const className =
        alert.priority === "Critical" || alert.priority === "Warning"
          ? "rating-high"
          : "rating-neutral";
      return `<tr><td>${escapeHtml(alert.title)}</td><td class="${className}">${escapeHtml(alert.message)}</td><td>${escapeHtml(relativeTime(alert.timestamp))}</td></tr>`;
    })
    .join("");

  document.getElementById("activity-rows").innerHTML =
    rows || '<tr><td colspan="3" class="meta">No recent activity</td></tr>';
}

function renderFocusRoster() {
  const rows = state.subjects
    .slice()
    .sort((a, b) => b.healthScore - a.healthScore)
    .slice(0, 5)
    .map((subject) => {
      const availableHeadroom = subject.creditLimit * (1 - subject.utilisationPercent / 100);
      return `<div class="focus-item"><div class="focus-top"><div class="focus-name">${escapeHtml(subject.name)}</div><span class="${scoreClass(subject.healthScore)}">Score ${escapeHtml(subject.healthScore)}</span></div><div class="meta">${escapeHtml(subject.status)} · ${escapeHtml(subject.type)} · ${escapeHtml(subject.assignedEmail)}</div><div class="meta">Available headroom ${escapeHtml(formatCurrency(availableHeadroom))}</div></div>`;
    })
    .join("");

  document.getElementById("focus-roster").innerHTML =
    rows || emptyState("No subject data available.");
}

function renderWarRoom() {
  renderPowerState();
  renderMetricCards();
  renderPriorityQueue();
  renderSpotlight();
  renderActivity();
  renderFocusRoster();
}

function renderSubjectOptions() {
  const optionRows = state.subjects
    .map((subject) => `<option value="${subject.id}">${escapeHtml(subject.name)}</option>`)
    .join("");
  const allOptions = `<option value="">All subjects</option>${optionRows}`;
  const createOptions = `<option value="">Select subject</option>${optionRows}`;

  ["comms-filter-subject", "emails-filter-subject"].forEach((id) => {
    const element = document.getElementById(id);
    const currentValue = element.value;
    element.innerHTML = allOptions;
    if (currentValue && state.subjects.some((subject) => subject.id === currentValue)) {
      element.value = currentValue;
    }
  });

  const createSelect = document.getElementById("comm-subject");
  const createValue = createSelect.value;
  createSelect.innerHTML = createOptions;
  if (createValue && state.subjects.some((subject) => subject.id === createValue)) {
    createSelect.value = createValue;
  }
}

function getFilteredSubjects() {
  return state.subjects.filter((subject) => {
    const search = state.filters.subjects.search.toLowerCase();
    const matchesSearch =
      !search ||
      subject.name.toLowerCase().includes(search) ||
      subject.assignedEmail.toLowerCase().includes(search) ||
      subject.assignedPhone.toLowerCase().includes(search);
    const matchesStatus =
      !state.filters.subjects.status || subject.status === state.filters.subjects.status;
    return matchesSearch && matchesStatus;
  });
}

function renderSubjects() {
  const items = getFilteredSubjects()
    .slice()
    .sort((a, b) => Number(b.isFlagged) - Number(a.isFlagged) || b.healthScore - a.healthScore);

  document.getElementById("subjects-summary").textContent = `${items.length} subject${items.length === 1 ? "" : "s"}`;
  document.getElementById("subjects-list").innerHTML = items.length
    ? items
        .map((subject) => {
          const availableHeadroom = subject.creditLimit * (1 - subject.utilisationPercent / 100);
          return `<tr>
            <td class="font-medium">${escapeHtml(subject.name)}</td>
            <td><span class="${makeBadgeClass("badge", subject.status)}">${escapeHtml(subject.status)}</span></td>
            <td><span class="${scoreClass(subject.healthScore)}">${escapeHtml(subject.healthScore)}</span></td>
            <td>${escapeHtml(subject.type)}</td>
            <td>${escapeHtml(subject.assignedEmail)}</td>
            <td>${escapeHtml(subject.assignedPhone)}</td>
            <td>${escapeHtml(subject.dateOfBirth || "—")}</td>
            <td>${escapeHtml(formatCurrency(subject.creditLimit))}</td>
            <td>${escapeHtml(formatCurrency(availableHeadroom))}</td>
            <td>${escapeHtml(subject.applications.length)}</td>
            <td class="text-truncate" title="${escapeHtml(subject.notes || "")}">${escapeHtml(subject.notes || "—")}</td>
            <td>
              <div class="row-actions">
                <button class="btn btn-ghost btn-sm" data-action="subject-edit" data-id="${subject.id}" type="button">Edit</button>
                <button class="btn btn-ghost btn-sm" data-action="subject-flag" data-id="${subject.id}" type="button">${subject.isFlagged ? "Unflag" : "Flag"}</button>
                <button class="btn btn-danger btn-sm" data-action="subject-archive" data-id="${subject.id}" type="button">Archive</button>
              </div>
            </td>
          </tr>`;
        })
        .join("")
    : `<tr><td colspan="12" class="empty-state" style="border:none; padding: 40px;">No subjects match the current filters.</td></tr>`;
}

function renderComms() {
  const items = state.comms.slice().sort((a, b) => Number(a.isRead) - Number(b.isRead));
  const unreadCount = items.filter((item) => !item.isRead).length;
  document.getElementById("comms-summary").textContent = `${items.length} items · ${unreadCount} unread`;
  document.getElementById("comms-list").innerHTML = items.length
    ? items
        .map((comm) => {
          const badgeClass = comm.isRead ? "badge" : "badge warn";
          const readAction = comm.isRead
            ? ""
            : `<button class="btn btn-ghost" data-action="comm-mark-read" data-id="${comm.id}" type="button">Mark read</button>`;
          return `<div class="record-row"><div class="record-top"><div><div class="record-title">${escapeHtml(comm.sender)}</div><div class="meta">${escapeHtml(comm.entityName)} · ${escapeHtml(comm.content)}</div></div><div class="record-tags"><span class="${badgeClass}">${escapeHtml(comm.type)}</span></div></div><div class="record-meta-grid"><div><span class="field-label">Phone</span><span class="field-value">${escapeHtml(comm.phoneNumber)}</span></div><div><span class="field-label">Time</span><span class="field-value">${escapeHtml(new Date(comm.timestamp).toLocaleString())}</span></div><div><span class="field-label">Duration</span><span class="field-value">${escapeHtml(comm.duration ?? "—")}</span></div><div><span class="field-label">Transcription</span><span class="field-value">${escapeHtml(comm.transcription || "—")}</span></div></div><div class="row-actions">${readAction}</div></div>`;
        })
        .join("")
    : emptyState("No communications found for the current filter.");
}

function renderEmails() {
  const items = state.emails
    .slice()
    .sort((a, b) => Number(b.isFlagged) - Number(a.isFlagged) || Number(a.isRead) - Number(b.isRead));
  const unreadCount = items.filter((item) => !item.isRead).length;
  const flaggedCount = items.filter((item) => item.isFlagged).length;
  document.getElementById("emails-summary").textContent = `${items.length} emails · ${unreadCount} unread · ${flaggedCount} flagged`;
  document.getElementById("emails-list").innerHTML = items.length
    ? items
        .map((email) => {
          const categoryClass = email.isFlagged ? "badge warn" : "badge";
          const readAction = email.isRead
            ? ""
            : `<button class="btn btn-ghost" data-action="email-mark-read" data-id="${email.id}" type="button">Mark read</button>`;
          return `<div class="record-row"><div class="record-top"><div><div class="record-title">${escapeHtml(email.subject)}</div><div class="meta">${escapeHtml(email.entityName)} · ${escapeHtml(email.senderAddress)}</div></div><div class="record-tags"><span class="${categoryClass}">${escapeHtml(email.category)}</span>${email.containsDollarAmount ? '<span class="badge success">Value</span>' : ""}</div></div><div class="record-meta-grid"><div><span class="field-label">Sender</span><span class="field-value">${escapeHtml(email.sender)}</span></div><div><span class="field-label">Alias</span><span class="field-value">${escapeHtml(email.alias)}</span></div><div><span class="field-label">Time</span><span class="field-value">${escapeHtml(new Date(email.timestamp).toLocaleString())}</span></div><div><span class="field-label">Snippet</span><span class="field-value">${escapeHtml(email.snippet)}</span></div></div><div class="row-actions">${readAction}<button class="btn btn-ghost" data-action="email-toggle-flag" data-id="${email.id}" type="button">${email.isFlagged ? "Unflag" : "Flag"}</button></div></div>`;
        })
        .join("")
    : emptyState("No emails found for the current filter.");
}

function renderAlerts() {
  const priorityWeight = { Critical: 0, Warning: 1, Info: 2 };
  const items = state.alerts
    .slice()
    .sort((a, b) => (priorityWeight[a.priority] ?? 9) - (priorityWeight[b.priority] ?? 9));
  const unreadCount = items.filter((item) => !item.isRead).length;
  document.getElementById("alerts-summary").textContent = `${items.length} alerts · ${unreadCount} unread`;
  document.getElementById("alerts-list").innerHTML = items.length
    ? items
        .map((alert) => {
          const readAction = alert.isRead
            ? ""
            : `<button class="btn btn-ghost" data-action="alert-mark-read" data-id="${alert.id}" type="button">Mark read</button>`;
          return `<div class="record-row"><div class="record-top"><div><div class="record-title">${escapeHtml(alert.title)}</div><div class="meta">${escapeHtml(alert.message)}</div></div><div class="record-tags"><span class="${makeBadgeClass("badge", alert.priority)}">${escapeHtml(alert.priority)}</span><span class="badge">${escapeHtml(alert.type)}</span></div></div><div class="record-meta-grid"><div><span class="field-label">Entity</span><span class="field-value">${escapeHtml(alert.entityName || "Global")}</span></div><div><span class="field-label">Time</span><span class="field-value">${escapeHtml(new Date(alert.timestamp).toLocaleString())}</span></div><div><span class="field-label">State</span><span class="field-value">${escapeHtml(alert.isRead ? "Read" : "Unread")}</span></div></div><div class="row-actions">${readAction}</div></div>`;
        })
        .join("")
    : emptyState("No alerts found for the current filter.");
}

function renderAll() {
  updateNavCounts();
  renderWarRoom();
  renderSubjectOptions();
  renderSubjects();
  renderComms();
  renderEmails();
  renderAlerts();
}

function parseNumber(value) {
  if (value === "" || value == null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
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
  state.comms = await trpcQuery(
    "communications.list",
    Object.keys(input).length ? input : undefined
  );
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
  setStatus("Syncing", "warn");
  try {
    await loadAllData();
    setStatus("Live", "ok");
  } catch (error) {
    setStatus("Offline", "bad");
    setAuthMessage(String(error));
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
  } catch (error) {
    setAuthMessage(String(error));
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
  } catch (error) {
    setAuthMessage(String(error));
  }
}

async function handleCreateSubject(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  try {
    const payload = {
      name: String(formData.get("name") || ""),
      type: String(formData.get("type") || "Person"),
      creditLimit: Number(formData.get("creditLimit") || 0),
      assignedPhone: String(formData.get("assignedPhone") || ""),
      assignedEmail: String(formData.get("assignedEmail") || ""),
      dateOfBirth: String(formData.get("dateOfBirth") || ""),
      address: String(formData.get("address") || ""),
      dlNumber: String(formData.get("dlNumber") || ""),
      dlCardNumber: String(formData.get("dlCardNumber") || ""),
      dlExpiry: String(formData.get("dlExpiry") || ""),
      medicareNumber: String(formData.get("medicareNumber") || ""),
      medicareExpiry: String(formData.get("medicareExpiry") || ""),
      passportNumber: String(formData.get("passportNumber") || ""),
      passportExpiry: String(formData.get("passportExpiry") || ""),
      creditNotes: String(formData.get("creditNotes") || ""),
      notes: String(formData.get("notes") || ""),
    };
    
    const clearScoreStr = formData.get("clearScore");
    if (clearScoreStr) {
      payload.clearScore = Number(clearScoreStr);
    }

    await trpcMutation("entities.create", payload);
    form.reset();
    await refreshAll();
    selectTab("subjects");
  } catch (error) {
    setAuthMessage(String(error));
  }
}

async function updateSubjectPrompt(id) {
  const subject = state.subjects.find((item) => item.id === id);
  if (!subject) return;

  const name = prompt("Name", subject.name) ?? subject.name;
  const status = prompt(
    "Status (Active|Pending|Dormant|At Risk|Archived)",
    subject.status
  ) ?? subject.status;
  const healthScore =
    prompt("Health Score", String(subject.healthScore)) ?? String(subject.healthScore);
  const creditLimit =
    prompt("Credit Limit", String(subject.creditLimit)) ?? String(subject.creditLimit);
  const monthlyBurn =
    prompt("Monthly Burn", String(subject.monthlyBurn)) ?? String(subject.monthlyBurn);
  const notes = prompt("Notes", subject.notes) ?? subject.notes;

  await trpcMutation("entities.update", {
    id,
    name,
    status,
    healthScore: parseNumber(healthScore),
    creditLimit: parseNumber(creditLimit),
    monthlyBurn: parseNumber(monthlyBurn),
    notes,
  });
  await refreshAll();
}

async function handleCreateComm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  const subjectId = String(formData.get("subjectId") || "");
  const subject = state.subjects.find((item) => item.id === subjectId);
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
    selectTab("comms");
  } catch (error) {
    setAuthMessage(String(error));
  }
}

async function handleRootClick(event) {
  const target = event.target;
  if (!(target instanceof HTMLElement)) return;
  const actionElement = target.closest("[data-action]");
  if (!(actionElement instanceof HTMLElement)) return;
  const action = actionElement.dataset.action;
  const id = actionElement.dataset.id;
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
  } catch (error) {
    setAuthMessage(String(error));
  }
}

function attachEventHandlers() {
  document.querySelectorAll(".tab-btn").forEach((button) => {
    button.addEventListener("click", () => selectTab(button.dataset.tab));
  });

  document.getElementById("login-form").addEventListener("submit", handleLoginSubmit);
  document
    .getElementById("register-form")
    .addEventListener("submit", handleRegisterSubmit);
  document
    .getElementById("subject-create-form")
    .addEventListener("submit", handleCreateSubject);
  document.getElementById("comm-create-form").addEventListener("submit", handleCreateComm);

  document.getElementById("btn-refresh-all").addEventListener("click", refreshAll);
  document.getElementById("btn-refresh-fab").addEventListener("click", refreshAll);

  document.getElementById("btn-me").addEventListener("click", async () => {
    try {
      const me = await trpcQuery("auth.me");
      setAuthUser(me);
      setAuthMessage(`Current user ${me.email}`);
    } catch (error) {
      setAuthMessage(String(error));
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
    state.filters.comms.subjectId = String(
      document.getElementById("comms-filter-subject").value || ""
    );
    state.filters.comms.type = String(document.getElementById("comms-filter-type").value || "");
    await loadComms();
    updateNavCounts();
    renderComms();
  });

  document.getElementById("emails-filter-apply").addEventListener("click", async () => {
    state.filters.emails.subjectId = String(
      document.getElementById("emails-filter-subject").value || ""
    );
    state.filters.emails.category = String(
      document.getElementById("emails-filter-category").value || ""
    );
    await loadEmails();
    updateNavCounts();
    renderEmails();
  });

  document.getElementById("alerts-filter-apply").addEventListener("click", async () => {
    state.filters.alerts.type = String(document.getElementById("alerts-filter-type").value || "");
    await loadAlerts();
    updateNavCounts();
    renderAlerts();
    renderActivity();
  });

  document.getElementById("alerts-mark-all").addEventListener("click", async () => {
    try {
      await trpcMutation("alerts.markAllRead", null);
      await refreshAll();
    } catch (error) {
      setAuthMessage(String(error));
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
