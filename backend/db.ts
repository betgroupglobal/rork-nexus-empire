import { z } from "zod";

export const EntityTypeEnum = z.enum(["Person", "Ltd", "Trust"]);
export const EntityStatusEnum = z.enum(["Active", "Pending", "Dormant", "At Risk", "Archived"]);
export const ApplicationStatusEnum = z.enum(["Submitted", "In Review", "Approved", "Declined", "Docs Needed", "Stalled"]);
export const CommTypeEnum = z.enum(["SMS", "Call", "Voicemail"]);
export const EmailCategoryEnum = z.enum(["Statement", "Approval", "Bank Notice", "ATO Notice", "General"]);
export const AlertTypeEnum = z.enum(["Stalled App", "Score Drop", "Verification", "New Comm", "Utilisation", "Dormant", "Application", "ClearScore"]);
export const AlertPriorityEnum = z.enum(["Critical", "Warning", "Info"]);

export const CreditApplicationSchema = z.object({
  id: z.string().uuid(),
  bank: z.string(),
  product: z.string(),
  status: ApplicationStatusEnum,
  progressPercent: z.number().int().min(0).max(100),
  submittedDate: z.string(),
  lastUpdateDate: z.string(),
  nextAction: z.string(),
  documents: z.string(),
});

export const EntitySchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  type: EntityTypeEnum,
  status: EntityStatusEnum,
  healthScore: z.number().int().min(0).max(100),
  creditLimit: z.number(),
  utilisationPercent: z.number(),
  monthlyBurn: z.number(),
  assignedPhone: z.string(),
  assignedEmail: z.string(),
  clearScore: z.number().int(),
  lastActivityDate: z.string(),
  isFlagged: z.boolean(),
  notes: z.string(),
  createdDate: z.string(),
  dateOfBirth: z.string(),
  address: z.string(),
  idNumber: z.string(),
  dlNumber: z.string().optional(),
  dlCardNumber: z.string().optional(),
  dlExpiry: z.string().optional(),
  medicareNumber: z.string().optional(),
  medicareExpiry: z.string().optional(),
  passportNumber: z.string().optional(),
  passportExpiry: z.string().optional(),
  creditNotes: z.string().optional(),
  applications: z.array(CreditApplicationSchema),
});

export const CommunicationSchema = z.object({
  id: z.string().uuid(),
  entityId: z.string().uuid(),
  entityName: z.string(),
  type: CommTypeEnum,
  sender: z.string(),
  content: z.string(),
  timestamp: z.string(),
  isRead: z.boolean(),
  phoneNumber: z.string(),
  duration: z.number().nullable().optional(),
  transcription: z.string().nullable().optional(),
});

export const EmailSchema = z.object({
  id: z.string().uuid(),
  entityId: z.string().uuid(),
  entityName: z.string(),
  sender: z.string(),
  senderAddress: z.string(),
  subject: z.string(),
  snippet: z.string(),
  category: EmailCategoryEnum,
  timestamp: z.string(),
  isRead: z.boolean(),
  isFlagged: z.boolean(),
  containsDollarAmount: z.boolean(),
  alias: z.string(),
});

export const AlertSchema = z.object({
  id: z.string().uuid(),
  entityId: z.string().uuid().nullable().optional(),
  entityName: z.string().nullable().optional(),
  type: AlertTypeEnum,
  priority: AlertPriorityEnum,
  title: z.string(),
  message: z.string(),
  timestamp: z.string(),
  isRead: z.boolean(),
});

export type CreditApplication = z.infer<typeof CreditApplicationSchema>;
export type Entity = z.infer<typeof EntitySchema>;
export type Communication = z.infer<typeof CommunicationSchema>;
export type Email = z.infer<typeof EmailSchema>;
export type NexusAlert = z.infer<typeof AlertSchema>;

const now = new Date();
const h = (hours: number) => new Date(now.getTime() - hours * 3600000).toISOString();
const d = (days: number) => new Date(now.getTime() - days * 86400000).toISOString();
const m = (months: number) => new Date(now.getTime() - months * 30 * 86400000).toISOString();

const e1Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567801";
const e2Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567802";
const e3Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567803";
const e4Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567804";
const e5Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567805";
const e6Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567806";
const e7Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567807";
const e8Id = "a1b2c3d4-e5f6-7890-abcd-ef1234567808";

const applicationsByEntity: Record<string, CreditApplication[]> = {
  [e1Id]: [
    { id: "b1000001-0000-0000-0000-000000000001", bank: "CBA", product: "Business Credit Line", status: "In Review", progressPercent: 72, submittedDate: d(26), lastUpdateDate: d(2), nextAction: "Upload updated BAS", documents: "ID, BAS, Bank Statements" },
    { id: "b1000001-0000-0000-0000-000000000002", bank: "Westpac", product: "Merchant Facility", status: "Submitted", progressPercent: 34, submittedDate: d(9), lastUpdateDate: d(1), nextAction: "Await assessor assignment", documents: "Merchant History" },
  ],
  [e2Id]: [
    { id: "b1000001-0000-0000-0000-000000000003", bank: "Westpac", product: "Platinum Card", status: "Approved", progressPercent: 100, submittedDate: d(41), lastUpdateDate: d(12), nextAction: "Card dispatched", documents: "Payslips, ID" },
  ],
  [e3Id]: [
    { id: "b1000001-0000-0000-0000-000000000004", bank: "CBA", product: "Trust Overdraft", status: "Docs Needed", progressPercent: 58, submittedDate: d(31), lastUpdateDate: d(3), nextAction: "Provide trust deed variation", documents: "Trust Deed, Financials" },
    { id: "b1000001-0000-0000-0000-000000000005", bank: "ANZ", product: "Business Loan", status: "Stalled", progressPercent: 44, submittedDate: d(53), lastUpdateDate: d(17), nextAction: "Follow up relationship manager", documents: "Tax Returns" },
  ],
  [e4Id]: [
    { id: "b1000001-0000-0000-0000-000000000006", bank: "NAB", product: "Credit Limit Increase", status: "Approved", progressPercent: 100, submittedDate: d(15), lastUpdateDate: d(4), nextAction: "Limit update processing", documents: "Management Accounts" },
  ],
  [e5Id]: [
    { id: "b1000001-0000-0000-0000-000000000007", bank: "ANZ", product: "Personal Loan", status: "Declined", progressPercent: 100, submittedDate: d(64), lastUpdateDate: d(30), nextAction: "Reapply after score recovery", documents: "Credit Report" },
  ],
  [e6Id]: [
    { id: "b1000001-0000-0000-0000-000000000008", bank: "Macquarie", product: "Business Card", status: "In Review", progressPercent: 66, submittedDate: d(18), lastUpdateDate: d(2), nextAction: "Confirm guarantor details", documents: "Director IDs" },
    { id: "b1000001-0000-0000-0000-000000000009", bank: "CBA", product: "Equipment Finance", status: "Submitted", progressPercent: 29, submittedDate: d(7), lastUpdateDate: h(20 / 24), nextAction: "Await valuation", documents: "Asset Quotes" },
  ],
  [e7Id]: [
    { id: "b1000001-0000-0000-0000-000000000010", bank: "ANZ", product: "Balance Transfer", status: "Stalled", progressPercent: 39, submittedDate: d(47), lastUpdateDate: d(20), nextAction: "Resolve verification mismatch", documents: "ID, Utility Bill" },
  ],
  [e8Id]: [
    { id: "b1000001-0000-0000-0000-000000000011", bank: "CBA", product: "Trust Card", status: "Docs Needed", progressPercent: 61, submittedDate: d(23), lastUpdateDate: d(5), nextAction: "Upload trustee minutes", documents: "Minutes, Trust Deed" },
  ],
};

interface StoredUser {
  id: string;
  email: string;
  passwordHash: string;
  name: string;
  createdAt: string;
}

export const db: {
  entities: Entity[];
  communications: Communication[];
  emails: Email[];
  alerts: NexusAlert[];
  users: StoredUser[];
} = {
  entities: [
    { id: e1Id, name: "Apex Holdings Pty Ltd", type: "Ltd" as const, status: "Active" as const, healthScore: 92, creditLimit: 75000, utilisationPercent: 12, monthlyBurn: 45, assignedPhone: "+61 4 5555 0101", assignedEmail: "apex@addy.io", clearScore: 845, lastActivityDate: h(3), isFlagged: false, notes: "Primary vehicle. CBA business account.", createdDate: m(14), dateOfBirth: "1990-02-14", address: "88 Collins St, Melbourne VIC", idNumber: "ABN-91-245-001-111", applications: applicationsByEntity[e1Id] ?? [] },
    { id: e2Id, name: "Jordan Mitchell", type: "Person" as const, status: "Active" as const, healthScore: 87, creditLimit: 45000, utilisationPercent: 8, monthlyBurn: 29, assignedPhone: "+61 4 5555 0202", assignedEmail: "j.mitchell@addy.io", clearScore: 812, lastActivityDate: d(1), isFlagged: false, notes: "Clean profile. Westpac personal.", createdDate: m(11), dateOfBirth: "1989-06-30", address: "14 Lakeview Rd, Sydney NSW", idNumber: "DL-NSW-3521947", applications: applicationsByEntity[e2Id] ?? [] },
    { id: e3Id, name: "Pinnacle Trust", type: "Trust" as const, status: "Pending" as const, healthScore: 78, creditLimit: 120000, utilisationPercent: 22, monthlyBurn: 52, assignedPhone: "+61 4 5555 0303", assignedEmail: "pinnacle@addy.io", clearScore: 788, lastActivityDate: d(4), isFlagged: true, notes: "High limit. Monitor utilisation closely.", createdDate: m(9), dateOfBirth: "2013-01-01", address: "Level 9, 200 Queen St, Brisbane QLD", idNumber: "TRUST-PIN-8821", applications: applicationsByEntity[e3Id] ?? [] },
    { id: e4Id, name: "Velocity Ventures Pty Ltd", type: "Ltd" as const, status: "Active" as const, healthScore: 95, creditLimit: 60000, utilisationPercent: 5, monthlyBurn: 38, assignedPhone: "+61 4 5555 0404", assignedEmail: "velocity@addy.io", clearScore: 867, lastActivityDate: h(8), isFlagged: false, notes: "NAB business. Excellent standing.", createdDate: m(7), dateOfBirth: "1994-11-03", address: "27 King St, Perth WA", idNumber: "ABN-13-982-221-004", applications: applicationsByEntity[e4Id] ?? [] },
    { id: e5Id, name: "Sarah Chen", type: "Person" as const, status: "Dormant" as const, healthScore: 55, creditLimit: 30000, utilisationPercent: 3, monthlyBurn: 22, assignedPhone: "+61 4 5555 0505", assignedEmail: "s.chen@addy.io", clearScore: 734, lastActivityDate: d(45), isFlagged: false, notes: "Needs reactivation. ANZ personal.", createdDate: m(18), dateOfBirth: "1992-10-11", address: "3 Bayview Ave, Adelaide SA", idNumber: "PP-AU-E72K11", applications: applicationsByEntity[e5Id] ?? [] },
    { id: e6Id, name: "Orion Group Pty Ltd", type: "Ltd" as const, status: "Active" as const, healthScore: 84, creditLimit: 90000, utilisationPercent: 18, monthlyBurn: 41, assignedPhone: "+61 4 5555 0606", assignedEmail: "orion@addy.io", clearScore: 801, lastActivityDate: d(2), isFlagged: false, notes: "Macquarie business. Strong history.", createdDate: m(6), dateOfBirth: "1986-03-19", address: "120 Hunter St, Newcastle NSW", idNumber: "ABN-54-210-998-441", applications: applicationsByEntity[e6Id] ?? [] },
    { id: e7Id, name: "Blake Thompson", type: "Person" as const, status: "At Risk" as const, healthScore: 38, creditLimit: 25000, utilisationPercent: 67, monthlyBurn: 35, assignedPhone: "+61 4 5555 0707", assignedEmail: "b.thompson@addy.io", clearScore: 621, lastActivityDate: d(12), isFlagged: true, notes: "ClearScore dropping. Reduce utilisation ASAP.", createdDate: m(20), dateOfBirth: "1988-09-04", address: "19 Chapel St, Melbourne VIC", idNumber: "DL-VIC-8844112", applications: applicationsByEntity[e7Id] ?? [] },
    { id: e8Id, name: "Summit Capital Trust", type: "Trust" as const, status: "Active" as const, healthScore: 71, creditLimit: 55000, utilisationPercent: 28, monthlyBurn: 50, assignedPhone: "+61 4 5555 0808", assignedEmail: "summit@addy.io", clearScore: 756, lastActivityDate: d(6), isFlagged: false, notes: "CBA trust account. Moderate activity.", createdDate: m(5), dateOfBirth: "2015-07-01", address: "45 Flinders Ln, Melbourne VIC", idNumber: "TRUST-SUM-4102", applications: applicationsByEntity[e8Id] ?? [] },
  ] as Entity[],

  communications: [
    { id: "c0000001-0000-0000-0000-000000000001", entityId: e1Id, entityName: "Apex Holdings Pty Ltd", type: "SMS" as const, sender: "CBA", content: "Your CBA Business account ending 4521 has a new transaction of $2,450.00.", timestamp: h(1), isRead: false, phoneNumber: "+61 4 5555 0101", duration: null, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000002", entityId: e2Id, entityName: "Jordan Mitchell", type: "Call" as const, sender: "+61 2 9293 8000", content: "Incoming call from Westpac Sydney", timestamp: h(3), isRead: true, phoneNumber: "+61 4 5555 0202", duration: 245, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000003", entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: "SMS" as const, sender: "NAB", content: "NAB: Your verification code is 847291. Do not share this code.", timestamp: h(0.4), isRead: false, phoneNumber: "+61 4 5555 0404", duration: null, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000004", entityId: e7Id, entityName: "Blake Thompson", type: "Voicemail" as const, sender: "ANZ Collections", content: "New voicemail received", timestamp: h(6), isRead: false, phoneNumber: "+61 4 5555 0707", duration: 42, transcription: "Hi, this is ANZ calling regarding your account ending in 8834. We'd like to discuss your current balance. Please call us back at 13 13 14 at your earliest convenience." },
    { id: "c0000001-0000-0000-0000-000000000005", entityId: e3Id, entityName: "Pinnacle Trust", type: "SMS" as const, sender: "CBA", content: "CBA: Monthly statement for account ending 7712 is now available in NetBank.", timestamp: h(12), isRead: true, phoneNumber: "+61 4 5555 0303", duration: null, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000006", entityId: e6Id, entityName: "Orion Group Pty Ltd", type: "SMS" as const, sender: "Macquarie", content: "Macquarie: A direct credit of $15,000.00 has been received into your business account.", timestamp: d(1), isRead: true, phoneNumber: "+61 4 5555 0606", duration: null, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000007", entityId: e1Id, entityName: "Apex Holdings Pty Ltd", type: "Call" as const, sender: "+61 2 9234 0200", content: "Incoming call from CBA Business Centre", timestamp: d(1), isRead: true, phoneNumber: "+61 4 5555 0101", duration: 180, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000008", entityId: e5Id, entityName: "Sarah Chen", type: "SMS" as const, sender: "ANZ", content: "ANZ: Your credit score has been updated. Log in to view your latest score.", timestamp: d(3), isRead: true, phoneNumber: "+61 4 5555 0505", duration: null, transcription: null },
    { id: "c0000001-0000-0000-0000-000000000009", entityId: e8Id, entityName: "Summit Capital Trust", type: "Voicemail" as const, sender: "Unknown", content: "New voicemail received", timestamp: d(2), isRead: false, phoneNumber: "+61 4 5555 0808", duration: 18, transcription: "This is a message for Summit Capital Trust regarding your recent application. Please contact our team." },
    { id: "c0000001-0000-0000-0000-000000000010", entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: "SMS" as const, sender: "NAB", content: "NAB: Your credit card payment of $500.00 has been processed successfully.", timestamp: d(2), isRead: true, phoneNumber: "+61 4 5555 0404", duration: null, transcription: null },
  ] as Communication[],

  emails: [
    { id: "e0000001-0000-4000-8000-000000000001", entityId: e1Id, entityName: "Apex Holdings Pty Ltd", sender: "CBA Business", senderAddress: "noreply@cba.com.au", subject: "Monthly Business Account Statement", snippet: "Your statement for the period ending 28 Feb 2026 is now available. Total credits: $42,500.00, Total debits: $38,200.00...", category: "Statement" as const, timestamp: h(2), isRead: false, isFlagged: false, containsDollarAmount: true, alias: "apex@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000002", entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", sender: "NAB Business", senderAddress: "business@nab.com.au", subject: "Credit Limit Increase Approved", snippet: "Congratulations! Your application for a credit limit increase has been approved. Your new limit is $60,000...", category: "Approval" as const, timestamp: h(5), isRead: false, isFlagged: true, containsDollarAmount: true, alias: "velocity@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000003", entityId: e7Id, entityName: "Blake Thompson", sender: "Australian Taxation Office", senderAddress: "noreply@ato.gov.au", subject: "Tax Return Due Reminder", snippet: "Your individual tax return for the 2025 financial year is due on 31 October 2026. Please lodge your return online...", category: "ATO Notice" as const, timestamp: d(1), isRead: false, isFlagged: false, containsDollarAmount: false, alias: "b.thompson@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000004", entityId: e3Id, entityName: "Pinnacle Trust", sender: "CBA Trust Services", senderAddress: "trust@cba.com.au", subject: "Trust Account Statement — February 2026", snippet: "Statement for Pinnacle Trust account ending 7712. Opening balance: $98,000.00. Closing balance: $93,600.00...", category: "Statement" as const, timestamp: d(1), isRead: true, isFlagged: false, containsDollarAmount: true, alias: "pinnacle@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000005", entityId: e6Id, entityName: "Orion Group Pty Ltd", sender: "Macquarie Business", senderAddress: "business@macquarie.com.au", subject: "New Business Credit Card Application", snippet: "Thank you for your application for a Macquarie Business Credit Card. We are currently reviewing your application...", category: "Approval" as const, timestamp: d(2), isRead: true, isFlagged: false, containsDollarAmount: false, alias: "orion@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000006", entityId: e2Id, entityName: "Jordan Mitchell", sender: "Westpac", senderAddress: "noreply@westpac.com.au", subject: "Your Westpac Statement is Ready", snippet: "Your February statement is now available. View it anytime in the Westpac app or Online Banking...", category: "Statement" as const, timestamp: d(3), isRead: true, isFlagged: false, containsDollarAmount: false, alias: "j.mitchell@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000007", entityId: e8Id, entityName: "Summit Capital Trust", sender: "CBA", senderAddress: "noreply@cba.com.au", subject: "Important: Account Verification Required", snippet: "We need to verify some details on your Summit Capital Trust account. Please log in to NetBank...", category: "General" as const, timestamp: d(4), isRead: false, isFlagged: true, containsDollarAmount: false, alias: "summit@addy.io" },
    { id: "e0000001-0000-4000-8000-000000000008", entityId: e5Id, entityName: "Sarah Chen", sender: "CreditSavvy", senderAddress: "hello@creditsavvy.com.au", subject: "Your Credit Score Has Changed", snippet: "Hi Sarah, your credit score has changed. Your new score is 734. Log in to see what's changed and get tips...", category: "General" as const, timestamp: d(5), isRead: true, isFlagged: false, containsDollarAmount: false, alias: "s.chen@addy.io" },
  ] as Email[],

  users: [] as StoredUser[],

  alerts: [
    { id: "al000001-0000-0000-0000-000000000001", entityId: e7Id, entityName: "Blake Thompson", type: "ClearScore" as const, priority: "Critical" as const, title: "ClearScore Dropping", message: "ClearScore dropped to 621 (-24 in 30 days). Utilisation at 67%. Immediate action required.", timestamp: h(2), isRead: false },
    { id: "al000001-0000-0000-0000-000000000002", entityId: e7Id, entityName: "Blake Thompson", type: "Utilisation" as const, priority: "Critical" as const, title: "High Utilisation", message: "Utilisation at 67% — well above 25% threshold. Reduce balance immediately.", timestamp: h(2), isRead: false },
    { id: "al000001-0000-0000-0000-000000000003", entityId: null, entityName: null, type: "New Comm" as const, priority: "Warning" as const, title: "Voicemail — ANZ", message: "Voicemail from ANZ Collections on Blake Thompson line. 42s. Transcription available.", timestamp: h(6), isRead: false },
    { id: "al000001-0000-0000-0000-000000000004", entityId: e5Id, entityName: "Sarah Chen", type: "Dormant" as const, priority: "Warning" as const, title: "Dormant Entity", message: "Sarah Chen has had no activity for 45 days. Consider reactivation or archive.", timestamp: d(1), isRead: false },
    { id: "al000001-0000-0000-0000-000000000005", entityId: e3Id, entityName: "Pinnacle Trust", type: "Utilisation" as const, priority: "Warning" as const, title: "Utilisation Rising", message: "Utilisation now at 22%, approaching 25% threshold.", timestamp: d(1), isRead: true },
    { id: "al000001-0000-0000-0000-000000000006", entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: "Application" as const, priority: "Info" as const, title: "Application Window", message: "Excellent standing (ClearScore 867). Ideal time to apply for additional credit.", timestamp: d(2), isRead: true },
    { id: "al000001-0000-0000-0000-000000000007", entityId: e8Id, entityName: "Summit Capital Trust", type: "New Comm" as const, priority: "Info" as const, title: "Verification Required", message: "CBA requires account verification for Summit Capital Trust.", timestamp: d(4), isRead: true },
  ] as NexusAlert[],
};
