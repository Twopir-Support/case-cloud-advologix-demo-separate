#!/usr/bin/env python3
"""Generate Matter Management (CaseCloud-style) object metadata from one spec.

Produces, under force-app/main/default:
  objects/<Obj>/<Obj>.object-meta.xml, fields/, listViews/, compactLayouts/
  layouts/<Obj>-<Label> Layout.layout-meta.xml
  tabs/<Obj>.tab-meta.xml
  permissionsets/Matter_Management_User.permissionset-meta.xml
  applications/Matter_Management.app-meta.xml

Run from the project root:  python3 scripts/generate_metadata.py
Apex, triggers, LWC and quick actions are hand-written and not touched.
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "force-app", "main", "default")
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'
TAB_MOTIF = os.environ.get("TAB_MOTIF", "Custom18: Form")

# ---------------------------------------------------------------- picklists
PRACTICE = ["Personal Injury", "Family Law", "Commercial Litigation", "Employment",
            "Corporate & Transactions", "Real Estate", "Immigration"]
MATTER_STATUS = ["Open", "Pending", "On Hold", "Settled", "Closed"]
MATTER_STAGE = ["Investigation", "Pleadings", "Discovery", "Negotiation", "Trial", "Resolution"]
INTAKE_STATUS = ["Requested", "In Progress", "Submitted", "Approved", "Rejected"]
INTAKE_SOURCE = ["Web Form", "Phone", "Referral", "Email", "Walk-in"]
CONFLICT_STATUS_INTAKE = ["Not Run", "Clear", "Potential Conflict", "Waived"]
CONFLICT_STATUS = ["Pending", "Clear", "Potential Conflict", "Waived"]
HIT_RESOLUTION = ["Unreviewed", "Not a Conflict", "Conflict", "Waived"]
ROLES = ["Client", "Responsible Attorney", "Associate", "Paralegal", "Opposing Party",
         "Opposing Counsel", "Expert Witness", "Witness", "Judge", "Insurance Adjuster",
         "Medical Provider", "Other"]
TK_LEVEL = ["Partner", "Senior Associate", "Associate", "Paralegal", "Legal Assistant"]
FEE_TYPE = ["Hourly", "Fixed Fee", "Contingency", "Capped Fee", "Retainer"]
DISPOSITION = ["Bill", "Do Not Bill", "Hold", "No Charge"]
BILLING_STATUS = ["Unprocessed", "Billed", "Not Billed"]
EXPENSE_CAT = ["Court Filing Fee", "Expert Fee", "Medical Records", "Deposition / Transcript",
               "Travel", "Copying & Printing", "Courier", "Other"]
CODE_TYPE = ["Task", "Activity", "Expense"]
INVOICE_STATUS = ["Draft", "Approved", "Sent", "Partially Paid", "Paid", "Void"]
LINE_TYPE = ["Fee", "Expense"]
HOLD_STATUS = ["Pending", "Acknowledged", "Released"]
PRIORITY = ["High", "Normal", "Low"]
ASSIGN_TO = ["Responsible Attorney", "Paralegal", "Matter Owner"]


# ---------------------------------------------------------------- field helpers
def F(api, label, ftype, **kw):
    d = {"api": api, "label": label, "type": ftype}
    d.update(kw)
    return d

def text(api, label, length=255, **kw): return F(api, label, "Text", length=length, **kw)
def longtext(api, label, **kw): return F(api, label, "LongTextArea", **kw)
def textarea(api, label, **kw): return F(api, label, "TextArea", **kw)
def date(api, label, **kw): return F(api, label, "Date", **kw)
def dt(api, label, **kw): return F(api, label, "DateTime", **kw)
def check(api, label, default=False, **kw): return F(api, label, "Checkbox", default=default, **kw)
def money(api, label, **kw): return F(api, label, "Currency", precision=16, scale=2, **kw)
def num(api, label, precision=10, scale=2, **kw): return F(api, label, "Number", precision=precision, scale=scale, **kw)
def pct(api, label, **kw): return F(api, label, "Percent", precision=6, scale=2, **kw)
def email(api, label, **kw): return F(api, label, "Email", **kw)
def pick(api, label, values, default=None, **kw): return F(api, label, "Picklist", values=values, default=default, **kw)
def lookup(api, label, ref, rel, rel_label, **kw): return F(api, label, "Lookup", ref=ref, rel=rel, rel_label=rel_label, **kw)
def md(api, label, ref, rel, rel_label, **kw): return F(api, label, "MasterDetail", ref=ref, rel=rel, rel_label=rel_label, **kw)
def formula(api, label, rtype, expr, **kw): return F(api, label, "Formula", rtype=rtype, expr=expr, **kw)
def autonum(api, label, fmt, **kw): return F(api, label, "AutoNumber", fmt=fmt, **kw)
def rollup(api, label, child, child_fk, op, field=None, filters=None, rtype="Currency", **kw):
    return F(api, label, "Summary", child=child, child_fk=child_fk, op=op, sfield=field,
             filters=filters or [], rtype=rtype, **kw)


# ---------------------------------------------------------------- object spec
# name: ("Text", label) or ("AutoNumber", label, format)
OBJECTS = [
 dict(api="Intake__c", label="Intake", plural="Intakes", name=("Text", "Intake Request Name"),
      history=True, activities=True, desc="A new legal request staged for conflict check and approval before a matter is opened.",
      fields=[
        pick("Status__c", "Status", INTAKE_STATUS, "Requested", track=True),
        pick("Source__c", "Source", INTAKE_SOURCE),
        pick("Type__c", "Type", PRACTICE, gvs="Matter_Type"),
        lookup("Primary_Account__c", "Primary Account", "Account", "Intakes", "Intakes"),
        lookup("Primary_Contact__c", "Primary Contact", "Contact", "Intakes", "Intakes"),
        text("Adverse_Party__c", "Adverse Party"),
        date("Incident_Date__c", "Incident Date"),
        date("Start_Date__c", "Start Date"),
        money("Estimated_Value__c", "Estimated Value"),
        lookup("Approver__c", "Approver", "User", "Intakes_To_Approve", "Intakes To Approve"),
        pick("Conflict_Status__c", "Conflict Status", CONFLICT_STATUS_INTAKE, "Not Run", track=True),
        lookup("Matter__c", "Matter", "Matter__c", "Intakes", "Intakes"),
        longtext("Description__c", "Description"),
      ],
      sections=[("Request", ["Name", "Primary_Account__c", "Primary_Contact__c", "Adverse_Party__c", "Type__c", "Source__c"],
                            ["Status__c", "Conflict_Status__c", "Approver__c", "Start_Date__c", "Incident_Date__c", "Estimated_Value__c", "Matter__c", "OwnerId"]),
                ("Details", ["Description__c"], [])],
      related=[("Conflict_Check__c.Intake__c", ["NAME", "Status__c", "Search_Term__c", "Hit_Count__c", "Run_Date__c"])],
      list_cols=["NAME", "Type__c", "Status__c", "Conflict_Status__c", "Start_Date__c"],
      compact=["Name", "Status__c", "Conflict_Status__c", "Type__c"],
      actions=["Intake__c.Conflict_Check", "Intake__c.Convert_to_Matter"]),

 dict(api="Matter__c", label="Matter", plural="Matters", name=("Text", "Matter Name"),
      history=True, activities=True, desc="The legal matter (case). Hub for participants, work, time, expenses, budgets and invoices.",
      fields=[
        autonum("Matter_Number__c", "Matter Number", "MAT-{00000}"),
        pick("Status__c", "Status", MATTER_STATUS, "Open", track=True),
        pick("Stage__c", "Stage", MATTER_STAGE, "Investigation", track=True),
        pick("Type__c", "Type", PRACTICE, gvs="Matter_Type"),
        lookup("Primary_Account__c", "Client Account", "Account", "Matters", "Matters"),
        lookup("Primary_Contact__c", "Client Contact", "Contact", "Matters", "Matters"),
        lookup("Responsible_Attorney__c", "Responsible Attorney", "User", "Responsible_Matters", "Responsible Matters"),
        lookup("Paralegal__c", "Paralegal", "User", "Paralegal_Matters", "Paralegal Matters"),
        lookup("Parent_Matter__c", "Parent Matter", "Matter__c", "Child_Matters", "Child Matters"),
        lookup("Rate_Group__c", "Rate Group", "Rate_Group__c", "Matters", "Matters"),
        date("Open_Date__c", "Open Date"),
        date("Close_Date__c", "Close Date"),
        date("Statute_of_Limitations__c", "Statute of Limitations"),
        text("Court__c", "Court"),
        text("Case_Number__c", "Court Case Number", 80),
        check("Legal_Hold__c", "Legal Hold", track=True),
        longtext("Description__c", "Description"),
        rollup("Total_Hours__c", "Total Hours", "Time__c", "Matter__c", "sum", "Time_in_Hours__c", rtype="Number"),
        rollup("Billable_Hours__c", "Billable Hours", "Time__c", "Matter__c", "sum", "Time_in_Hours__c",
               [("Billable__c", "equals", "True")], rtype="Number"),
        rollup("Total_Time_Value__c", "Total Time Value", "Time__c", "Matter__c", "sum", "Total_Amount__c"),
        rollup("Unbilled_Time_Value__c", "Unbilled Time (WIP)", "Time__c", "Matter__c", "sum", "Total_Amount__c",
               [("Status__c", "equals", "Unprocessed"), ("Disposition__c", "equals", "Bill")]),
        rollup("Total_Expenses__c", "Total Expenses", "Expense__c", "Matter__c", "sum", "Amount__c"),
        rollup("Unbilled_Expenses__c", "Unbilled Expenses", "Expense__c", "Matter__c", "sum", "Amount__c",
               [("Status__c", "equals", "Unprocessed"), ("Disposition__c", "equals", "Bill")]),
        rollup("Total_Invoiced__c", "Total Invoiced", "Invoice__c", "Matter__c", "sum", "Total_Amount__c",
               [("Status__c", "notEqual", "Void")]),
        rollup("Total_Paid__c", "Total Paid", "Invoice__c", "Matter__c", "sum", "Amount_Paid__c",
               [("Status__c", "notEqual", "Void")]),
        rollup("Budget_Total__c", "Budget Total", "Budget__c", "Matter__c", "sum", "Total_Budget__c",
               [("Active__c", "equals", "True")]),
        formula("Budget_Remaining__c", "Budget Remaining", "Currency",
                "Budget_Total__c - (Total_Time_Value__c + Total_Expenses__c)"),
        formula("Budget_Used__c", "Budget Used %", "Percent",
                "IF(Budget_Total__c > 0, (Total_Time_Value__c + Total_Expenses__c) / Budget_Total__c, 0)"),
        formula("Matter_Age__c", "Matter Age (in days)", "Number",
                "IF(ISBLANK(Open_Date__c), 0, IF(ISBLANK(Close_Date__c), TODAY() - Open_Date__c, Close_Date__c - Open_Date__c))", scale=0),
      ],
      sections=[("Matter", ["Name", "Matter_Number__c", "Primary_Account__c", "Primary_Contact__c", "Type__c", "Parent_Matter__c", "Rate_Group__c"],
                           ["Status__c", "Stage__c", "Responsible_Attorney__c", "Paralegal__c", "Open_Date__c", "Close_Date__c", "Legal_Hold__c", "OwnerId"]),
                ("Court", ["Court__c", "Case_Number__c"], ["Statute_of_Limitations__c", "Matter_Age__c"]),
                ("Financials", ["Total_Hours__c", "Billable_Hours__c", "Total_Time_Value__c", "Unbilled_Time_Value__c", "Total_Expenses__c", "Unbilled_Expenses__c"],
                               ["Budget_Total__c", "Budget_Remaining__c", "Budget_Used__c", "Total_Invoiced__c", "Total_Paid__c"]),
                ("Description", ["Description__c"], [])],
      related=[("Participant__c.Matter__c", ["NAME", "Participant_Name__c", "Role__c", "Auto_Added__c"]),
               ("Time__c.Matter__c", ["NAME", "Entry_Date__c", "Timekeeper__c", "Time_in_Hours__c", "Rate__c", "Total_Amount__c", "Disposition__c", "Status__c"]),
               ("Expense__c.Matter__c", ["NAME", "Expense_Date__c", "Category__c", "Amount__c", "Disposition__c", "Status__c"]),
               ("Matter_Fee_Arrangement__c.Matter__c", ["NAME", "Fee_Type__c", "Default_for_Fees__c", "Default_for_Expenses__c", "Discount_Percentage__c"]),
               ("Budget__c.Matter__c", ["NAME", "Fee_Budget__c", "Expense_Budget__c", "Total_Budget__c", "Active__c"]),
               ("Invoice__c.Matter__c", ["NAME", "Invoice_Date__c", "Status__c", "Total_Amount__c", "Balance_Due__c"]),
               ("Rate__c.Matter__c", ["NAME", "Timekeeper__c", "Hourly_Rate__c", "Effective_Date__c", "Default__c"]),
               ("Matter_Legal_Hold_Acknowledgement__c.Matter__c", ["NAME", "Custodian_Contact__c", "Custodian_User__c", "Status__c", "Notice_Sent__c", "Acknowledged_On__c"]),
               ("Conflict_Check__c.Matter__c", ["NAME", "Status__c", "Search_Term__c", "Hit_Count__c"]),
               ("Activity_Plan__c.Matter__c", ["NAME", "Activity_Plan_Template__c", "Start_Date__c"]),
               ("Intake__c.Matter__c", ["NAME", "Type__c", "Status__c"]),
               ("Matter__c.Parent_Matter__c", ["NAME", "Matter_Number__c", "Status__c"])],
      list_cols=["NAME", "Matter_Number__c", "Primary_Account__c", "Type__c", "Status__c", "Stage__c", "Responsible_Attorney__c", "Open_Date__c"],
      compact=["Name", "Matter_Number__c", "Primary_Account__c", "Status__c", "Stage__c", "Responsible_Attorney__c"],
      actions=["Matter__c.Apply_Activity_Plan", "Matter__c.Generate_Invoice"]),

 dict(api="Participant__c", label="Participant", plural="Participants", name=("AutoNumber", "Participant Number", "PRT-{00000}"),
      master=True, desc="A person or organisation involved in a matter, with their role on that matter.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Participants", "Participants"),
        pick("Role__c", "Role", ROLES),
        lookup("Account__c", "Account", "Account", "Matter_Participations", "Matter Participations"),
        lookup("Contact__c", "Contact", "Contact", "Matter_Participations", "Matter Participations"),
        lookup("Staff__c", "Staff", "User", "Matter_Participations", "Matter Participations"),
        text("Other_Name__c", "Other Name"),
        formula("Participant_Name__c", "Participant Name", "Text",
                'IF(NOT(ISBLANK(Contact__c)), Contact__r.FirstName & " " & Contact__r.LastName, '
                'IF(NOT(ISBLANK(Staff__c)), Staff__r.FirstName & " " & Staff__r.LastName, '
                'IF(NOT(ISBLANK(Account__c)), Account__r.Name, Other_Name__c)))'),
        check("Auto_Added__c", "Auto Added"),
        textarea("Notes__c", "Notes"),
      ],
      sections=[("Participant", ["Name", "Matter__c", "Role__c", "Participant_Name__c"], ["Account__c", "Contact__c", "Staff__c", "Other_Name__c", "Auto_Added__c"]),
                ("Notes", ["Notes__c"], [])],
      related=[],
      list_cols=["NAME", "Matter__c", "Participant_Name__c", "Role__c"],
      actions=[]),

 dict(api="Conflict_Check__c", label="Conflict Check", plural="Conflict Checks", name=("AutoNumber", "Conflict Check Number", "CC-{00000}"),
      desc="A conflict-of-interest search run for an intake or a matter.",
      fields=[
        text("Search_Term__c", "Search Term"),
        textarea("Description__c", "Description"),
        lookup("Intake__c", "Intake", "Intake__c", "Conflict_Checks", "Conflict Checks"),
        lookup("Matter__c", "Matter", "Matter__c", "Conflict_Checks", "Conflict Checks"),
        pick("Status__c", "Status", CONFLICT_STATUS, "Pending"),
        dt("Run_Date__c", "Run Date"),
        lookup("Reviewed_By__c", "Reviewed By", "User", "Reviewed_Conflict_Checks", "Reviewed Conflict Checks"),
        rollup("Hit_Count__c", "Hit Count", "Conflict_Check_Result__c", "Conflict_Check__c", "count", rtype="Number"),
        rollup("Unreviewed_Hits__c", "Unreviewed Hits", "Conflict_Check_Result__c", "Conflict_Check__c", "count",
               filters=[("Resolution__c", "equals", "Unreviewed")], rtype="Number"),
        longtext("Notes__c", "Review Notes"),
      ],
      sections=[("Conflict Check", ["Name", "Search_Term__c", "Description__c", "Intake__c", "Matter__c"], ["Status__c", "Run_Date__c", "Hit_Count__c", "Unreviewed_Hits__c", "Reviewed_By__c"]),
                ("Review", ["Notes__c"], [])],
      related=[("Conflict_Check_Result__c.Conflict_Check__c", ["NAME", "Matched_Term__c", "Matched_Name__c", "Matched_Object__c", "Context__c", "Resolution__c"])],
      list_cols=["NAME", "Search_Term__c", "Intake__c", "Matter__c", "Status__c", "Run_Date__c"],
      actions=[]),

 dict(api="Conflict_Check_Result__c", label="Conflict Check Result", plural="Conflict Check Results", name=("AutoNumber", "Result Number", "CCR-{000000}"),
      master=True, desc="One existing record that matched a conflict search term.",
      fields=[
        md("Conflict_Check__c", "Conflict Check", "Conflict_Check__c", "Results", "Conflict Check Results"),
        text("Matched_Term__c", "Matched Term"),
        text("Matched_Name__c", "Matched Name"),
        text("Matched_Object__c", "Matched Object", 80),
        text("Matched_Record_Id__c", "Matched Record Id", 18),
        text("Context__c", "Context"),
        pick("Resolution__c", "Resolution", HIT_RESOLUTION, "Unreviewed"),
      ],
      sections=[("Result", ["Name", "Conflict_Check__c", "Matched_Term__c", "Matched_Name__c"], ["Matched_Object__c", "Matched_Record_Id__c", "Context__c", "Resolution__c"])],
      related=[], list_cols=["NAME", "Conflict_Check__c", "Matched_Name__c", "Context__c", "Resolution__c"], actions=[]),

 dict(api="Timekeeper__c", label="Timekeeper", plural="Timekeepers", name=("Text", "Timekeeper Name"),
      desc="A person who records billable time, with default and cost rates.",
      fields=[
        lookup("User__c", "User", "User", "Timekeepers", "Timekeepers"),
        pick("Level__c", "Level", TK_LEVEL),
        money("Default_Rate__c", "Default Hourly Rate"),
        money("Cost_Rate__c", "Cost Rate"),
        text("Bar_Number__c", "Bar Number", 40),
        email("Email__c", "Email"),
        check("Active__c", "Active", True),
      ],
      sections=[("Timekeeper", ["Name", "User__c", "Level__c", "Bar_Number__c", "Email__c"], ["Default_Rate__c", "Cost_Rate__c", "Active__c", "OwnerId"])],
      related=[("Rate__c.Timekeeper__c", ["NAME", "Matter__c", "Rate_Group__c", "Hourly_Rate__c", "Effective_Date__c"]),
               ("Time__c.Timekeeper__c", ["NAME", "Matter__c", "Entry_Date__c", "Time_in_Hours__c", "Total_Amount__c"])],
      list_cols=["NAME", "Level__c", "Default_Rate__c", "Cost_Rate__c", "Active__c"], actions=[]),

 dict(api="Rate_Group__c", label="Rate Group", plural="Rate Groups", name=("Text", "Rate Group Name"),
      desc="A named set of timekeeper rates that can be applied to many matters.",
      fields=[textarea("Description__c", "Description"), check("Active__c", "Active", True)],
      sections=[("Rate Group", ["Name", "Description__c"], ["Active__c", "OwnerId"])],
      related=[("Rate__c.Rate_Group__c", ["NAME", "Timekeeper__c", "Hourly_Rate__c", "Effective_Date__c"]),
               ("Matter__c.Rate_Group__c", ["NAME", "Matter_Number__c", "Status__c"])],
      list_cols=["NAME", "Active__c"], actions=[]),

 dict(api="Rate__c", label="Rate", plural="Rates", name=("AutoNumber", "Rate Number", "RT-{00000}"),
      desc="Hourly rate for a timekeeper, either on a matter or in a rate group.",
      fields=[
        lookup("Timekeeper__c", "Timekeeper", "Timekeeper__c", "Rates", "Rates"),
        lookup("Matter__c", "Matter", "Matter__c", "Rates", "Rates"),
        lookup("Rate_Group__c", "Rate Group", "Rate_Group__c", "Rates", "Rates"),
        money("Hourly_Rate__c", "Hourly Rate"),
        date("Effective_Date__c", "Effective Date"),
        check("Default__c", "Default"),
      ],
      sections=[("Rate", ["Name", "Timekeeper__c", "Matter__c", "Rate_Group__c"], ["Hourly_Rate__c", "Effective_Date__c", "Default__c"])],
      related=[], list_cols=["NAME", "Timekeeper__c", "Matter__c", "Rate_Group__c", "Hourly_Rate__c", "Effective_Date__c"], actions=[]),

 dict(api="Fee_Arrangement__c", label="Fee Arrangement", plural="Fee Arrangements", name=("Text", "Fee Arrangement Name"),
      desc="Firm-level fee arrangement template (hourly, fixed, contingency, capped, retainer).",
      fields=[
        pick("Fee_Type__c", "Fee Type", FEE_TYPE),
        money("Fee_Arrangement_Price__c", "Fee Arrangement Price"),
        pct("Contingency_Percentage__c", "Contingency %"),
        money("Cap_Amount__c", "Cap Amount"),
        pct("Discount_Percentage__c", "Discount %"),
        check("Active__c", "Active", True),
        textarea("Description__c", "Description"),
      ],
      sections=[("Fee Arrangement", ["Name", "Fee_Type__c", "Description__c", "Active__c"], ["Fee_Arrangement_Price__c", "Contingency_Percentage__c", "Cap_Amount__c", "Discount_Percentage__c"])],
      related=[("Matter_Fee_Arrangement__c.Source_Fee_Arrangement__c", ["NAME", "Matter__c", "Fee_Type__c", "Start_Date__c"])],
      list_cols=["NAME", "Fee_Type__c", "Fee_Arrangement_Price__c", "Contingency_Percentage__c", "Cap_Amount__c", "Active__c"], actions=[]),

 dict(api="Matter_Fee_Arrangement__c", label="Matter Fee Arrangement", plural="Matter Fee Arrangements", name=("AutoNumber", "MFA Number", "MFA-{00000}"),
      master=True, desc="The fee terms agreed on one matter, copied from a firm fee arrangement.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Fee_Arrangements", "Matter Fee Arrangements"),
        lookup("Source_Fee_Arrangement__c", "Source Fee Arrangement", "Fee_Arrangement__c", "Matter_Fee_Arrangements", "Matter Fee Arrangements"),
        pick("Fee_Type__c", "Fee Type", FEE_TYPE),
        money("Fee_Arrangement_Price__c", "Fee Arrangement Price"),
        pct("Contingency_Percentage__c", "Contingency %"),
        money("Cap_Amount__c", "Cap Amount"),
        pct("Discount_Percentage__c", "Discount %"),
        check("Default_for_Fees__c", "Default for Fees"),
        check("Default_for_Expenses__c", "Default for Expenses"),
        date("Start_Date__c", "Start Date"),
        date("End_Date__c", "End Date"),
        pick("Recurrence__c", "Recurrence", ["One-Time", "Monthly", "Quarterly"], "One-Time"),
        date("NextBillDate__c", "Next Bill Date"),
        date("LastBillDate__c", "Last Bill Date"),
        textarea("Description__c", "Description"),
      ],
      sections=[("Matter Fee Arrangement", ["Name", "Matter__c", "Source_Fee_Arrangement__c", "Fee_Type__c", "Start_Date__c", "End_Date__c"],
                 ["Fee_Arrangement_Price__c", "Contingency_Percentage__c", "Cap_Amount__c", "Discount_Percentage__c", "Default_for_Fees__c", "Default_for_Expenses__c", "Recurrence__c", "NextBillDate__c", "LastBillDate__c"]),
                ("Description", ["Description__c"], [])],
      related=[("Time__c.Matter_Fee_Arrangement__c", ["NAME", "Entry_Date__c", "Time_in_Hours__c", "Total_Amount__c"]),
               ("Expense__c.Matter_Fee_Arrangement__c", ["NAME", "Expense_Date__c", "Amount__c"])],
      list_cols=["NAME", "Matter__c", "Fee_Type__c", "Default_for_Fees__c", "Default_for_Expenses__c"], actions=[]),

 dict(api="UTBMS_Code__c", label="UTBMS Code", plural="UTBMS Codes", name=("Text", "Code"),
      desc="Uniform Task-Based Management System code for time and expense coding.",
      fields=[text("Description__c", "Description"), pick("Code_Type__c", "Code Type", CODE_TYPE), text("Phase__c", "Phase", 80)],
      sections=[("Code", ["Name", "Code_Type__c"], ["Description__c", "Phase__c"])],
      related=[], list_cols=["NAME", "Code_Type__c", "Description__c", "Phase__c"], actions=[]),

 dict(api="Time__c", label="Time", plural="Time", name=("Text", "Time Name"),
      master=True, desc="A unit of work recorded by a timekeeper against a matter.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Time_Entries", "Time Entries"),
        lookup("Timekeeper__c", "Timekeeper", "Timekeeper__c", "Time_Entries", "Time Entries"),
        date("Entry_Date__c", "Entry Date"),
        num("Time_in_Hours__c", "Time in Hours", 5, 2),
        money("Rate__c", "Rate"),
        formula("Total_Amount__c", "Total Amount", "Currency", 'IF(ISPICKVAL(Disposition__c, "No Charge"), 0, Time_in_Hours__c * Rate__c)'),
        lookup("Task_Code__c", "Task Code", "UTBMS_Code__c", "Task_Time_Entries", "Time Entries (Task Code)"),
        lookup("Activity_Code__c", "Activity Code", "UTBMS_Code__c", "Activity_Time_Entries", "Time Entries (Activity Code)"),
        check("Billable__c", "Billable", True),
        pick("Disposition__c", "Disposition", DISPOSITION, "Bill"),
        pick("Status__c", "Status", BILLING_STATUS, "Unprocessed"),
        lookup("Matter_Fee_Arrangement__c", "Matter Fee Arrangement", "Matter_Fee_Arrangement__c", "Time_Entries", "Time Entries"),
        lookup("Source_Fee_Arrangement__c", "Source Fee Arrangement", "Fee_Arrangement__c", "Time", "Time"),
        lookup("Invoice__c", "Invoice", "Invoice__c", "Time", "Time"),
        check("Exported__c", "Exported"),
        formula("Time_Entry_Lag__c", "Time Entry Lag", "Number", "DATEVALUE(CreatedDate) - Entry_Date__c", scale=0),
        text("Source_Activity_Id__c", "Source Activity Id", 18),
        longtext("Narrative__c", "Narrative"),
      ],
      sections=[("Time", ["Name", "Matter__c", "Timekeeper__c", "Entry_Date__c", "Time_in_Hours__c", "Rate__c", "Total_Amount__c"],
                         ["Task_Code__c", "Activity_Code__c", "Billable__c", "Disposition__c", "Status__c", "Matter_Fee_Arrangement__c", "Source_Fee_Arrangement__c", "Invoice__c", "Exported__c", "Time_Entry_Lag__c"]),
                ("Narrative", ["Narrative__c"], [])],
      related=[], list_cols=["NAME", "Matter__c", "Timekeeper__c", "Entry_Date__c", "Time_in_Hours__c", "Total_Amount__c", "Disposition__c", "Status__c"], actions=[]),

 dict(api="Expense__c", label="Expense", plural="Expenses", name=("AutoNumber", "Expense Number", "EX-{000000}"),
      master=True, desc="A cost incurred on a matter, billable to the client or absorbed.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Expenses", "Matter Expenses"),
        date("Expense_Date__c", "Expense Date"),
        pick("Category__c", "Category", EXPENSE_CAT),
        money("Amount__c", "Amount"),
        lookup("Expense_Code__c", "Expense Code", "UTBMS_Code__c", "Expenses", "Matter Expenses"),
        lookup("Vendor__c", "Vendor", "Account", "Vendor_Expenses", "Matter Expenses (Vendor)"),
        check("Billable__c", "Billable", True),
        pick("Disposition__c", "Disposition", DISPOSITION, "Bill"),
        pick("Status__c", "Status", BILLING_STATUS, "Unprocessed"),
        lookup("Matter_Fee_Arrangement__c", "Matter Fee Arrangement", "Matter_Fee_Arrangement__c", "Expenses", "Matter Expenses"),
        lookup("Source_Fee_Arrangement__c", "Source Fee Arrangement", "Fee_Arrangement__c", "Expenses", "Expenses"),
        lookup("Invoice__c", "Invoice", "Invoice__c", "Expenses", "Expenses"),
        textarea("Description__c", "Description"),
      ],
      sections=[("Expense", ["Name", "Matter__c", "Expense_Date__c", "Category__c", "Amount__c", "Vendor__c", "Expense_Code__c"],
                            ["Billable__c", "Disposition__c", "Status__c", "Matter_Fee_Arrangement__c", "Source_Fee_Arrangement__c", "Invoice__c"]),
                ("Description", ["Description__c"], [])],
      related=[], list_cols=["NAME", "Matter__c", "Expense_Date__c", "Category__c", "Amount__c", "Status__c"], actions=[]),

 dict(api="Budget__c", label="Budget", plural="Budgets", name=("Text", "Budget Name"),
      master=True, desc="Fee and expense budget for a matter.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Budgets", "Matter Budgets"),
        money("Fee_Budget__c", "Fee Budget"),
        money("Expense_Budget__c", "Expense Budget"),
        formula("Total_Budget__c", "Total Budget", "Currency", "BLANKVALUE(Fee_Budget__c, 0) + BLANKVALUE(Expense_Budget__c, 0)"),
        date("Budget_Start__c", "Budget Start"),
        date("Budget_End__c", "Budget End"),
        check("Active__c", "Active", True),
        check("Locked__c", "Locked"),
        textarea("Notes__c", "Notes"),
      ],
      sections=[("Budget", ["Name", "Matter__c", "Budget_Start__c", "Budget_End__c", "Notes__c"], ["Fee_Budget__c", "Expense_Budget__c", "Total_Budget__c", "Active__c", "Locked__c"])],
      related=[], list_cols=["NAME", "Matter__c", "Fee_Budget__c", "Expense_Budget__c", "Total_Budget__c", "Active__c"], actions=[]),

 dict(api="Invoice__c", label="Invoice", plural="Invoices", name=("AutoNumber", "Invoice Number", "INV-{00000}"),
      master=True, desc="Client invoice generated from unbilled time and expenses on a matter.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Invoices", "Matter Invoices"),
        lookup("Account__c", "Bill To Account", "Account", "Matter_Invoices", "Matter Invoices"),
        date("Invoice_Date__c", "Invoice Date"),
        date("Due_Date__c", "Due Date"),
        date("Period_Start__c", "Period Start"),
        date("Period_End__c", "Period End"),
        pick("Status__c", "Status", INVOICE_STATUS, "Draft", track=False),
        rollup("Fees_Subtotal__c", "Fees Subtotal", "Invoice_Line_Item__c", "Invoice__c", "sum", "Amount__c", [("Line_Type__c", "equals", "Fee")]),
        rollup("Expenses_Subtotal__c", "Expenses Subtotal", "Invoice_Line_Item__c", "Invoice__c", "sum", "Amount__c", [("Line_Type__c", "equals", "Expense")]),
        money("Discount_Amount__c", "Discount Amount"),
        money("Total_Amount__c", "Total Amount"),
        money("Amount_Paid__c", "Amount Paid"),
        formula("Balance_Due__c", "Balance Due", "Currency", "BLANKVALUE(Total_Amount__c, 0) - BLANKVALUE(Amount_Paid__c, 0)"),
        textarea("Notes__c", "Notes"),
      ],
      sections=[("Invoice", ["Name", "Matter__c", "Account__c", "Status__c", "Invoice_Date__c", "Due_Date__c", "Period_Start__c", "Period_End__c"],
                            ["Fees_Subtotal__c", "Expenses_Subtotal__c", "Discount_Amount__c", "Total_Amount__c", "Amount_Paid__c", "Balance_Due__c"]),
                ("Notes", ["Notes__c"], [])],
      related=[("Invoice_Line_Item__c.Invoice__c", ["NAME", "Line_Type__c", "Line_Date__c", "Description__c", "Quantity__c", "Rate__c", "Amount__c"])],
      list_cols=["NAME", "Matter__c", "Account__c", "Invoice_Date__c", "Status__c", "Total_Amount__c", "Balance_Due__c"],
      compact=["Name", "Matter__c", "Status__c", "Total_Amount__c", "Balance_Due__c"],
      actions=["Invoice__c.Void_Invoice"]),

 dict(api="Invoice_Line_Item__c", label="Invoice Line Item", plural="Invoice Line Items", name=("AutoNumber", "Line Number", "IL-{000000}"),
      master=True, desc="One fee or expense line on a matter invoice.",
      fields=[
        md("Invoice__c", "Invoice", "Invoice__c", "Invoice_Line_Items", "Invoice Line Items"),
        pick("Line_Type__c", "Line Type", LINE_TYPE),
        lookup("Time__c", "Time", "Time__c", "Invoice_Lines", "Invoice Lines"),
        lookup("Expense__c", "Expense", "Expense__c", "Invoice_Lines", "Invoice Lines"),
        lookup("Timekeeper__c", "Timekeeper", "Timekeeper__c", "Invoice_Lines", "Invoice Lines"),
        date("Line_Date__c", "Line Date"),
        textarea("Description__c", "Description"),
        num("Quantity__c", "Quantity", 8, 2),
        money("Rate__c", "Rate"),
        money("Amount__c", "Amount"),
        text("UTBMS_Code__c", "UTBMS Code", 20),
      ],
      sections=[("Line", ["Name", "Invoice__c", "Line_Type__c", "Line_Date__c", "Description__c", "UTBMS_Code__c"],
                         ["Time__c", "Expense__c", "Timekeeper__c", "Quantity__c", "Rate__c", "Amount__c"])],
      related=[], list_cols=["NAME", "Invoice__c", "Line_Type__c", "Line_Date__c", "Amount__c"], actions=[]),

 dict(api="Matter_Legal_Hold_Acknowledgement__c", label="Matter Legal Hold Acknowledgement", plural="Matter Legal Hold Acknowledgements", name=("AutoNumber", "Acknowledgement Number", "LHA-{00000}"),
      master=True, desc="A custodian's acknowledgement of a legal hold notice on a matter.",
      fields=[
        md("Matter__c", "Matter", "Matter__c", "Legal_Hold_Acks", "Legal Hold Acknowledgements"),
        lookup("Custodian_Contact__c", "Custodian Contact", "Contact", "Legal_Hold_Acks", "Legal Hold Acknowledgements"),
        lookup("Custodian_User__c", "Custodian User", "User", "Legal_Hold_Acks", "Legal Hold Acknowledgements"),
        pick("Status__c", "Status", HOLD_STATUS, "Pending"),
        dt("Notice_Sent__c", "Notice Sent"),
        dt("Acknowledged_On__c", "Acknowledged On"),
        dt("Released_On__c", "Released On"),
      ],
      sections=[("Acknowledgement", ["Name", "Matter__c", "Custodian_Contact__c", "Custodian_User__c"], ["Status__c", "Notice_Sent__c", "Acknowledged_On__c", "Released_On__c"])],
      related=[], list_cols=["NAME", "Matter__c", "Custodian_Contact__c", "Custodian_User__c", "Status__c"], actions=[]),

 dict(api="Activity_Plan_Template__c", label="Activity Plan Template", plural="Activity Plan Templates", name=("Text", "Template Name"),
      desc="Reusable list of dated tasks applied to a new matter by practice area.",
      fields=[pick("Type__c", "Matter Type", PRACTICE, gvs="Matter_Type"), check("Active__c", "Active", True), textarea("Description__c", "Description")],
      sections=[("Template", ["Name", "Type__c"], ["Active__c", "Description__c"])],
      related=[("Activity_Plan__c.Activity_Plan_Template__c", ["NAME", "Matter__c", "Start_Date__c"]), ("Activity_Plan_Template_Item__c.Activity_Plan_Template__c", ["NAME", "Step_Order__c", "Subject__c", "Days_Offset__c", "Assign_To__c", "Priority__c"])],
      list_cols=["NAME", "Type__c", "Active__c"], actions=[]),

 dict(api="Activity_Plan_Template_Item__c", label="Activity Plan Template Item", plural="Activity Plan Template Items", name=("AutoNumber", "Step Number", "STEP-{00000}"),
      master=True, desc="One task in an activity plan template.",
      fields=[
        md("Activity_Plan_Template__c", "Activity Plan Template", "Activity_Plan_Template__c", "Items", "Activity Plan Template Items"),
        text("Subject__c", "Subject"),
        num("Step_Order__c", "Step Order", 4, 0),
        num("Days_Offset__c", "Due (Days After Open)", 4, 0),
        pick("Priority__c", "Priority", PRIORITY, "Normal"),
        pick("Assign_To__c", "Assign To", ASSIGN_TO, "Responsible Attorney"),
        textarea("Description__c", "Description"),
      ],
      sections=[("Step", ["Name", "Activity_Plan_Template__c", "Step_Order__c", "Subject__c"], ["Days_Offset__c", "Priority__c", "Assign_To__c", "Description__c"])],
      related=[], list_cols=["NAME", "Activity_Plan_Template__c", "Step_Order__c", "Subject__c", "Days_Offset__c"], actions=[]),

 dict(api="Activity_Plan__c", label="Activity Plan", plural="Activity Plans", name=("Text", "Activity Plan Name"),
      activities=True, desc="An activity plan template applied to a matter, account or contact; its tasks are created on the record.",
      fields=[
        lookup("Activity_Plan_Template__c", "Activity Plan Template", "Activity_Plan_Template__c", "Activity_Plans", "Activity Plans"),
        lookup("Matter__c", "Matter", "Matter__c", "Activity_Plans", "Activity Plans"),
        lookup("Account__c", "Account", "Account", "Activity_Plans", "Activity Plans"),
        lookup("Contact__c", "Contact", "Contact", "Activity_Plans", "Activity Plans"),
        date("Start_Date__c", "Start Date"),
        num("Number_of_Tasks__c", "Number of Tasks", 4, 0),
      ],
      sections=[("Activity Plan", ["Name", "Activity_Plan_Template__c", "Start_Date__c"], ["Matter__c", "Account__c", "Contact__c", "Number_of_Tasks__c", "OwnerId"])],
      related=[], list_cols=["NAME", "Activity_Plan_Template__c", "Matter__c", "Start_Date__c", "Number_of_Tasks__c"], actions=[]),
]

import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spec_extensions as _ext
_H = dict(text=text, longtext=longtext, textarea=textarea, date=date, dt=dt, check=check, money=money, num=num, pct=pct,
          email=email, pick=pick, lookup=lookup, md=md, formula=formula, autonum=autonum, rollup=rollup, PRACTICE=PRACTICE)
_ext.extend(OBJECTS, _H)
STANDARD_FIELDS = _ext.standard_fields(_H)
PAGE_TABS = [("Billing_Preview", "Billing Preview", "Custom24: Money"), ("Batch_Time", "Batch Time", "Custom25: Alarm clock"),
             ("Batch_Conflict_Check", "Batch Conflict Check", "Custom14: Hands"), ("Legal_Tools", "Legal Tools", "Custom18: Form")]

APP_TABS = ["standard-home", "Intake__c", "Matter__c", "Conflict_Check__c", "Time__c",
            "Expense__c", "Invoice__c", "Timekeeper__c", "Rate_Group__c", "Fee_Arrangement__c",
            "Activity_Plan_Template__c", "Activity_Plan__c", "Budget_Template__c", "UTBMS_Code__c", "UTBMS_Code_Set__c",
            "Skill_Certification__c", "Transaction__c", "Billing_Preview", "Batch_Time", "Batch_Conflict_Check", "Legal_Tools", "standard-Account", "standard-Contact",
            "standard-report", "standard-Dashboard"]
APEX_CLASSES = ["IntakeService", "ConflictSearchService", "BillingService", "ActionPlansUtilitiesExternal",
                "RatesService", "MatterTriggerHandler", "BillableTriggerHandler", "LegalHoldGuard", "LegalHoldService",
                "BudgetService", "TransactionService", "TransactionsBatch", "RecurrenceService", "MatterStatusRuleBatch",
                "ActivityTimeService", "FocusMatterService", "DateCalculationService", "BillingPreviewController",
                "MatterTimelineController", "BatchTimeController", "SettlementCalculatorController", "TaskChecklistController",
                "MatterManagementSettings", "RateTriggerHandler", "TimekeeperService", "LegalHoldCallback"]


# ---------------------------------------------------------------- writers
def w(path, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n' + body.strip() + "\n")

def x(tag, val):
    return f"<{tag}>{escape(str(val))}</{tag}>"

def bool_s(b): return "true" if b else "false"

def field_xml(o, f):
    t = f["type"]
    p = [x("fullName", f["api"]), x("label", f["label"])]
    if f.get("help"): p.append(x("inlineHelpText", f["help"]))
    if t == "Text":
        u = bool_s(f.get("unique"))
        p += [x("length", f["length"]), x("required", bool_s(f.get("required"))), x("type", "Text"), x("unique", u), x("externalId", u)]
        if f.get("unique"): p.append(x("caseSensitive", "false"))
    elif t == "LongTextArea":
        p += [x("length", 32768), x("type", "LongTextArea"), x("visibleLines", 5)]
    elif t == "TextArea":
        p += [x("required", "false"), x("type", "TextArea")]
    elif t in ("Date", "DateTime", "Email"):
        p += [x("required", "false"), x("type", t)]
        if t == "Email": p += [x("unique", "false"), x("externalId", "false")]
    elif t == "Checkbox":
        p += [x("defaultValue", bool_s(f["default"])), x("type", "Checkbox")]
    elif t in ("Currency", "Number", "Percent"):
        p += [x("precision", f["precision"]), x("required", "false"), x("scale", f["scale"]), x("type", t)]
        if t == "Number": p += [x("unique", "false"), x("externalId", "false")]
    elif t == "Picklist" and f.get("gvs"):
        p += [x("required", "false"), x("type", "Picklist"),
              f"<valueSet><restricted>true</restricted>{x('valueSetName', f['gvs'])}</valueSet>"]
    elif t == "Picklist":
        vals = "".join(
            f"<value>{x('fullName', v)}{x('default', bool_s(v == f.get('default')))}{x('label', v)}</value>"
            for v in f["values"])
        p += [x("required", "false"), x("type", "Picklist"),
              f"<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{vals}</valueSetDefinition></valueSet>"]
    elif t == "Lookup":
        p += [x("deleteConstraint", "SetNull"), x("referenceTo", f["ref"]), x("relationshipLabel", f["rel_label"]),
              x("relationshipName", f["rel"]), x("required", "false"), x("type", "Lookup")]
    elif t == "MasterDetail":
        p += [x("referenceTo", f["ref"]), x("relationshipLabel", f["rel_label"]), x("relationshipName", f["rel"]),
              x("relationshipOrder", 0), x("reparentableMasterDetail", "false"), x("type", "MasterDetail"),
              x("writeRequiresMasterRead", "false")]
    elif t == "Formula":
        rt = f["rtype"]
        p += [x("formula", f["expr"]), x("formulaTreatBlanksAs", "BlankAsZero")]
        if rt in ("Currency", "Number", "Percent"):
            p += [x("precision", 18), x("scale", f.get("scale", 2))]
        p += [x("required", "false"), x("type", rt)]
        if rt == "Number": p += [x("unique", "false"), x("externalId", "false")]
    elif t == "AutoNumber":
        p += [x("displayFormat", f["fmt"]), x("externalId", "false"), x("type", "AutoNumber")]
    elif t == "Summary":
        if f["op"] != "count":
            p.append(x("summarizedField", f"{f['child']}.{f['sfield']}"))
        for (fld, op, val) in f["filters"]:
            p.append(f"<summaryFilterItems>{x('field', f['child'] + '.' + fld)}{x('operation', op)}{x('value', val)}</summaryFilterItems>")
        p += [x("summaryForeignKey", f"{f['child']}.{f['child_fk']}"), x("summaryOperation", f["op"]), x("type", "Summary")]
    else:
        raise ValueError(t)
    if f.get("track"): p.append(x("trackHistory", "true"))
    if o.get("history") and not f.get("track") and t not in ("Formula", "Summary", "LongTextArea", "AutoNumber"):
        p.append(x("trackHistory", "false"))
    return f"<CustomField {NS}>{''.join(p)}</CustomField>"

def object_xml(o):
    nm = o["name"]
    if nm[0] == "AutoNumber":
        name = f"<nameField>{x('displayFormat', nm[2])}{x('label', nm[1])}{x('trackHistory', 'false')}{x('type', 'AutoNumber')}</nameField>"
    else:
        name = f"<nameField>{x('label', nm[1])}{x('trackHistory', 'false')}{x('type', 'Text')}</nameField>"
    sharing = "ControlledByParent" if o.get("master") else "ReadWrite"
    compact = x("compactLayoutAssignment", "Matter_Management_Compact") if o.get("compact") else ""
    return f"""<CustomObject {NS}>
  {compact}
  {x('deploymentStatus', 'Deployed')}
  {x('description', o['desc'])}
  {x('enableActivities', bool_s(o.get('activities')))}
  {x('enableBulkApi', 'true')}
  {x('enableFeeds', 'false')}
  {x('enableHistory', bool_s(o.get('history')))}
  {x('enableLicensing', 'false')}
  {x('enableReports', 'true')}
  {x('enableSearch', 'true')}
  {x('enableSharing', 'true')}
  {x('enableStreamingApi', 'true')}
  {x('externalSharingModel', 'Private' if not o.get('master') else 'ControlledByParent')}
  {x('label', o['label'])}
  {name}
  {x('pluralLabel', o['plural'])}
  {x('sharingModel', sharing)}
  {x('visibility', 'Public')}
</CustomObject>"""

def field_map(o):
    return {f["api"]: f for f in o["fields"]}

def behavior(o, api):
    fm = field_map(o)
    if api == "Name":
        return "Readonly" if o["name"][0] == "AutoNumber" else "Required"
    if api == "OwnerId":
        return "Edit"
    f = fm[api]
    if f["type"] in ("Formula", "Summary", "AutoNumber"):
        return "Readonly"
    if f["type"] == "MasterDetail":
        return "Required"
    return "Edit"

def layout_xml(o):
    secs = []
    for (label, left, right) in o["sections"]:
        cols = ""
        for col in (left, right):
            items = "".join(f"<layoutItems>{x('behavior', behavior(o, a))}{x('field', a)}</layoutItems>" for a in col)
            cols += f"<layoutColumns>{items}</layoutColumns>"
        style = "TwoColumnsTopToBottom" if right else "OneColumn"
        if not right:
            items = "".join(f"<layoutItems>{x('behavior', behavior(o, a))}{x('field', a)}</layoutItems>" for a in left)
            cols = f"<layoutColumns>{items}</layoutColumns>"
        secs.append(f"<layoutSections><customLabel>true</customLabel><detailHeading>true</detailHeading><editHeading>true</editHeading>{x('label', label)}{cols}{x('style', style)}</layoutSections>")
    secs.append("<layoutSections><customLabel>false</customLabel><detailHeading>true</detailHeading><editHeading>false</editHeading><label>System Information</label>"
                "<layoutColumns><layoutItems><behavior>Readonly</behavior><field>CreatedById</field></layoutItems></layoutColumns>"
                "<layoutColumns><layoutItems><behavior>Readonly</behavior><field>LastModifiedById</field></layoutItems></layoutColumns>"
                "<style>TwoColumnsTopToBottom</style></layoutSections>")
    actions = ""
    if o.get("actions"):
        items = ""
        order = 0
        for a in o["actions"]:
            items += f"<platformActionListItems>{x('actionName', a)}{x('actionType', 'QuickAction' if '.' in a else 'StandardButton')}{x('sortOrder', order)}</platformActionListItems>"
            order += 1
        for std in ["Edit", "Delete", "ChangeOwnerOne"] if not o.get("master") else ["Edit", "Delete"]:
            items += f"<platformActionListItems>{x('actionName', std)}{x('actionType', 'StandardButton')}{x('sortOrder', order)}</platformActionListItems>"
            order += 1
        actions = f"<platformActionList>{x('actionListContext', 'Record')}{items}</platformActionList>"
    rels = ""
    for (rl, cols) in o.get("related", []):
        flds = "".join(x("fields", c) for c in (cols or []))
        rels += f"<relatedLists>{flds}{x('relatedList', rl)}</relatedLists>"
    if o.get("activities"):
        rels += "<relatedLists><relatedList>RelatedActivityList</relatedList></relatedLists>"
        rels += "<relatedLists><relatedList>RelatedHistoryList</relatedList></relatedLists>"
    if o.get("history"):
        rels += "<relatedLists><relatedList>RelatedEntityHistoryList</relatedList></relatedLists>"
    return f"""<Layout {NS}>
  {''.join(secs)}
  {actions}
  {rels}
  <showEmailCheckbox>false</showEmailCheckbox>
  <showHighlightsPanel>false</showHighlightsPanel>
  <showInteractionLogPanel>false</showInteractionLogPanel>
  <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
  <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>"""

def listview_xml(o):
    cols = "".join(x("columns", c) for c in o["list_cols"])
    return f"<ListView {NS}>{x('fullName', 'All')}{cols}{x('filterScope', 'Everything')}{x('label', 'All')}</ListView>"

def compact_xml(o):
    flds = "".join(x("fields", c) for c in o["compact"])
    return f"<CompactLayout {NS}>{x('fullName', 'Matter_Management_Compact')}{flds}{x('label', 'Matter Management')}</CompactLayout>"

def tab_xml(o):
    return f"<CustomTab {NS}>{x('customObject', 'true')}{x('motif', TAB_MOTIF)}</CustomTab>"

def permset_xml():
    parts = [x("description", "Full access to the Matter Management app, its objects, fields, Apex services and tabs."),
             x("hasActivationRequired", "false"), x("label", "Matter Management User")]
    parts.append(f"<applicationVisibilities>{x('application', 'Matter_Management')}{x('visible', 'true')}</applicationVisibilities>")
    for c in APEX_CLASSES:
        parts.append(f"<classAccesses>{x('apexClass', c)}{x('enabled', 'true')}</classAccesses>")
    for o in OBJECTS:
        for f in o["fields"]:
            if f["type"] == "MasterDetail" or f.get("required"):
                continue
            editable = f["type"] not in ("Formula", "Summary", "AutoNumber")
            parts.append(f"<fieldPermissions>{x('editable', bool_s(editable))}{x('field', o['api'] + '.' + f['api'])}{x('readable', 'true')}</fieldPermissions>")
    for o in OBJECTS:
        parts.append(f"<objectPermissions>{x('allowCreate', 'true')}{x('allowDelete', 'true')}{x('allowEdit', 'true')}{x('allowRead', 'true')}"
                     f"{x('modifyAllRecords', 'true')}{x('object', o['api'])}{x('viewAllRecords', 'true')}</objectPermissions>")
    for o in OBJECTS:
        if o["api"] in APP_TABS:
            parts.append(f"<tabSettings>{x('tab', o['api'])}{x('visibility', 'Visible')}</tabSettings>")
    for o in OBJECTS:
        for dev, _lbl in o.get("record_types", []):
            parts.append(f"<recordTypeVisibilities>{x('recordType', o['api'] + '.' + dev)}{x('visible', 'true')}</recordTypeVisibilities>")
    for obj, f in STANDARD_FIELDS:
        for target in (["Task", "Event"] if obj == "Activity" else [obj]):
            parts.append(f"<fieldPermissions>{x('editable', 'true')}{x('field', target + '.' + f['api'])}{x('readable', 'true')}</fieldPermissions>")
    for api, _l, _m in PAGE_TABS:
        parts.append(f"<tabSettings>{x('tab', api)}{x('visibility', 'Visible')}</tabSettings>")
    body = "".join(sorted(parts, key=lambda s: s[:s.index('>')]))  # keep element groups together
    return f"<PermissionSet {NS}>{body}</PermissionSet>"

def app_xml():
    tabs = "".join(x("tabs", t) for t in APP_TABS)
    ov = ""
    pages = [] if os.environ.get("MM_SKIP_OVERRIDES") else [("Matter_Record_Page", "Matter__c", "View"), ("Matter_Management_Home", "standard-home", "Tab")]
    for page, obj, action in pages:
        ov += (f"<actionOverrides>{x('actionName', action)}{x('content', page)}{x('formFactor', 'Large')}"
               f"{x('skipRecordTypeSelect', 'false')}{x('type', 'Flexipage')}{x('pageOrSobjectType', obj)}</actionOverrides>")
    return f"""<CustomApplication {NS}>
  {ov}
  <brand><headerColor>#0D6560</headerColor><shouldOverrideOrgTheme>false</shouldOverrideOrgTheme></brand>
  {x('description', 'Legal case management: intake, conflict checks, matters, time, expenses, budgets and billing.')}
  <formFactors>Small</formFactors><formFactors>Large</formFactors>
  <isNavPersonalizationDisabled>false</isNavPersonalizationDisabled>
  <isNavTabPersistenceDisabled>false</isNavTabPersistenceDisabled>
  {x('label', 'Matter Management')}
  <navType>Standard</navType>
  {tabs}
  <uiType>Lightning</uiType>
</CustomApplication>"""

def main():
    for o in OBJECTS:
        od = os.path.join(ROOT, "objects", o["api"])
        w(os.path.join(od, f"{o['api']}.object-meta.xml"), object_xml(o))
        for f in o["fields"]:
            w(os.path.join(od, "fields", f"{f['api']}.field-meta.xml"), field_xml(o, f))
        w(os.path.join(od, "listViews", "All.listView-meta.xml"), listview_xml(o))
        if o.get("compact"):
            w(os.path.join(od, "compactLayouts", "Matter_Management_Compact.compactLayout-meta.xml"), compact_xml(o))
        w(os.path.join(ROOT, "layouts", f"{o['api']}-{o['label']} Layout.layout-meta.xml"), layout_xml(o))
        if o["api"] in APP_TABS:
            w(os.path.join(ROOT, "tabs", f"{o['api']}.tab-meta.xml"), tab_xml(o))
    for o in OBJECTS:
        for dev, lbl in o.get("record_types", []):
            w(os.path.join(ROOT, "objects", o["api"], "recordTypes", f"{dev}.recordType-meta.xml"),
              f"<RecordType {NS}>{x('fullName', dev)}{x('active', 'true')}{x('label', lbl)}</RecordType>")
    for obj, f in STANDARD_FIELDS:
        w(os.path.join(ROOT, "objects", obj, "fields", f"{f['api']}.field-meta.xml"), field_xml({}, f))
    sd = os.path.join(ROOT, "objects", "Matter_Management_Settings__c")
    w(os.path.join(sd, "Matter_Management_Settings__c.object-meta.xml"),
      f"<CustomObject {NS}>{x('customSettingsType', 'Hierarchy')}{x('description', 'Admin switches for Matter Management automation.')}"
      f"{x('enableFeeds', 'false')}{x('label', 'Matter Management Settings')}{x('visibility', 'Public')}</CustomObject>")
    for api, lbl, typ in _ext.SETTINGS_FIELDS:
        body = (x("defaultValue", "true" if api == "Send_Legal_Hold_Emails__c" else "false") + x("type", "Checkbox")) if typ == "Checkbox" \
            else (x("length", 255) + x("required", "false") + x("type", "Text") + x("unique", "false") + x("externalId", "false"))
        w(os.path.join(sd, "fields", f"{api}.field-meta.xml"), f"<CustomField {NS}>{x('fullName', api)}{x('label', lbl)}{body}</CustomField>")
    md_dir = os.path.join(ROOT, "objects", "Matter_Status_Rule__mdt")
    w(os.path.join(md_dir, "Matter_Status_Rule__mdt.object-meta.xml"),
      f"<CustomObject {NS}>{x('description', 'Rules that move matters to a target status when their conditions match. Evaluated by MatterStatusRuleBatch.')}"
      f"{x('label', 'Matter Status Rule')}{x('pluralLabel', 'Matter Status Rules')}{x('visibility', 'Public')}</CustomObject>")
    ops = "".join(f"<value>{x('fullName', v)}{x('default', 'false')}{x('label', v)}</value>" for v in
                  ["equals", "not equal to", "less than", "greater than", "older than days", "is blank", "is not blank"])
    for api, lbl, kind in [("Active__c", "Active", "cb"), ("Target_Status__c", "Target Status", "t"), ("Field_1__c", "Field 1", "t"),
                           ("Operator_1__c", "Operator 1", "p"), ("Value_1__c", "Value 1", "t"), ("Field_2__c", "Field 2", "t"),
                           ("Operator_2__c", "Operator 2", "p"), ("Value_2__c", "Value 2", "t"), ("Order__c", "Order", "n")]:
        if kind == "cb": body = x("defaultValue", "false") + x("type", "Checkbox")
        elif kind == "p": body = x("required", "false") + x("type", "Picklist") + f"<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{ops}</valueSetDefinition></valueSet>"
        elif kind == "n": body = x("precision", 4) + x("required", "false") + x("scale", 0) + x("type", "Number") + x("unique", "false") + x("externalId", "false")
        else: body = x("length", 255) + x("required", "false") + x("type", "Text") + x("unique", "false") + x("externalId", "false")
        w(os.path.join(md_dir, "fields", f"{api}.field-meta.xml"),
          f"<CustomField {NS}>{x('fullName', api)}{x('externalId', 'false') if kind=='p' else ''}{x('fieldManageability', 'DeveloperControlled')}{x('label', lbl)}{body}</CustomField>".replace(x('externalId','false')+x('fieldManageability','DeveloperControlled'), x('fieldManageability','DeveloperControlled')))
    w(os.path.join(ROOT, "customMetadata", "Matter_Status_Rule.Close_Settled_Matters.md-meta.xml"),
      f"<CustomMetadata xmlns=\"http://soap.sforce.com/2006/04/metadata\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">"
      f"{x('label', 'Close Settled Matters')}{x('protected', 'false')}"
      + "".join(f"<values><field>{k}</field><value xsi:type=\"xsd:{t}\">{escape(v)}</value></values>" for k, t, v in [
          ("Active__c", "boolean", "true"), ("Target_Status__c", "string", "Closed"), ("Field_1__c", "string", "Status__c"),
          ("Operator_1__c", "string", "equals"), ("Value_1__c", "string", "Settled"), ("Field_2__c", "string", "LastModifiedDate"),
          ("Operator_2__c", "string", "older than days"), ("Value_2__c", "string", "30"), ("Order__c", "double", "1")])
      + "</CustomMetadata>")
    for api, lbl, motif in PAGE_TABS:
        w(os.path.join(ROOT, "tabs", f"{api}.tab-meta.xml"), f"<CustomTab {NS}>{x('flexiPage', api + '_Page')}{x('label', lbl)}{x('motif', motif)}</CustomTab>")
    vals = "".join(f"<customValue>{x('fullName', v)}{x('default', 'false')}{x('label', v)}</customValue>" for v in PRACTICE)
    w(os.path.join(ROOT, "globalValueSets", "Matter_Type.globalValueSet-meta.xml"),
      f"<GlobalValueSet {NS}>{vals}{x('description', 'Matter types shared by Intake, Matter and Activity Plan Template.')}{x('masterLabel', 'Matter Type')}{x('sorted', 'false')}</GlobalValueSet>")
    w(os.path.join(ROOT, "permissionsets", "Matter_Management_User.permissionset-meta.xml"), permset_xml())
    w(os.path.join(ROOT, "applications", "Matter_Management.app-meta.xml"), app_xml())
    nf = sum(len(o["fields"]) for o in OBJECTS)
    print(f"Generated {len(OBJECTS)} objects, {nf} fields, layouts, tabs, list views, permission set and app.")

if __name__ == "__main__":
    main()
