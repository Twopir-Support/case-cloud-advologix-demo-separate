"""Second-wave CaseCloud features: objects and fields added on top of the base spec.
Imported by generate_metadata.py, which passes in its field helpers."""


def extend(OBJECTS, h):
    text, longtext, textarea, date, dt, check, money, num, pct, email, pick, lookup, md, formula, autonum, rollup = (
        h["text"], h["longtext"], h["textarea"], h["date"], h["dt"], h["check"], h["money"], h["num"], h["pct"],
        h["email"], h["pick"], h["lookup"], h["md"], h["formula"], h["autonum"], h["rollup"])
    PRACTICE = h["PRACTICE"]
    by = {o["api"]: o for o in OBJECTS}

    def add(api, fields, section=None, cols=None):
        by[api]["fields"].extend(fields)
        if section:
            by[api]["sections"].append(section)

    def related(api, rl, cols, first=False):
        lst = by[api]["related"]
        (lst.insert(0, (rl, cols)) if first else lst.append((rl, cols)))

    # ---------- new objects
    new = [
     dict(api="Cross_Reference_Matter__c", label="Cross Reference Matter", plural="Cross Reference Matters",
          name=("AutoNumber", "Cross Reference Number", "XRM-{00000}"), master=True,
          desc="Links a matter to another related matter (appeal, coverage, consolidated case).",
          fields=[md("Matter__c", "Matter", "Matter__c", "Cross_Reference_Matters", "Cross Reference Matters"),
                  lookup("Related_Matter__c", "Related Matter", "Matter__c", "Cross_Referenced_By", "Cross Referenced By"),
                  pick("Relationship__c", "Relationship", ["Related", "Appeal", "Consolidated", "Coverage", "Successor", "Prior Matter"], "Related"),
                  textarea("Notes__c", "Notes")],
          sections=[("Cross Reference", ["Name", "Matter__c", "Related_Matter__c"], ["Relationship__c", "Notes__c"])],
          related=[], list_cols=["NAME", "Matter__c", "Related_Matter__c", "Relationship__c"], actions=[]),
     dict(api="Offer_and_Demand__c", label="Offer and Demand", plural="Offers and Demands",
          name=("AutoNumber", "Offer/Demand Number", "OD-{00000}"), master=True,
          desc="Settlement offers and demands exchanged on a matter.",
          fields=[md("Matter__c", "Matter", "Matter__c", "Offers_and_Demands", "Offers and Demands"),
                  pick("Type__c", "Type", ["Demand", "Offer", "Counter-Demand", "Counter-Offer"]),
                  money("Amount__c", "Amount"), date("Date__c", "Date"), date("Expiration_Date__c", "Expiration Date"),
                  text("Party__c", "Party"), pick("Status__c", "Status", ["Open", "Accepted", "Rejected", "Expired", "Withdrawn"], "Open"),
                  textarea("Notes__c", "Notes")],
          sections=[("Offer and Demand", ["Name", "Matter__c", "Type__c", "Amount__c", "Party__c"], ["Date__c", "Expiration_Date__c", "Status__c", "Notes__c"])],
          related=[], list_cols=["NAME", "Matter__c", "Type__c", "Amount__c", "Date__c", "Status__c"], actions=[]),
     dict(api="Comment__c", label="Comment", plural="Comments",
          name=("AutoNumber", "Comment Number", "CMT-{000000}"), master=True,
          desc="Internal comments on a matter.",
          fields=[md("Matter__c", "Matter", "Matter__c", "Comments", "Comments"),
                  pick("Comment_Type__c", "Comment Type", ["General", "Internal", "Client Update", "Court Update"], "General"),
                  longtext("Comment__c", "Comment")],
          sections=[("Comment", ["Name", "Matter__c", "Comment_Type__c"], []), ("Body", ["Comment__c"], [])],
          related=[], list_cols=["NAME", "Matter__c", "Comment_Type__c"], actions=[]),
     dict(api="Budget_Detail__c", label="Budget Detail", plural="Budget Details",
          name=("AutoNumber", "Budget Detail Number", "BD-{00000}"), master=True,
          desc="One UTBMS phase or task line in a budget. Details roll up to the budget and matter.",
          fields=[md("Budget__c", "Budget", "Budget__c", "Budget_Details", "Budget Details"),
                  lookup("UTBMS_Code__c", "UTBMS Code", "UTBMS_Code__c", "Budget_Details", "Budget Details"),
                  text("Description__c", "Description"), num("Hours__c", "Hours", 8, 2),
                  money("Fee_Amount__c", "Fee Amount"), money("Expense_Amount__c", "Expense Amount"),
                  formula("Total_Amount__c", "Total Amount", "Currency", "BLANKVALUE(Fee_Amount__c, 0) + BLANKVALUE(Expense_Amount__c, 0)")],
          sections=[("Budget Detail", ["Name", "Budget__c", "UTBMS_Code__c", "Description__c"], ["Hours__c", "Fee_Amount__c", "Expense_Amount__c", "Total_Amount__c"])],
          related=[], list_cols=["NAME", "Budget__c", "UTBMS_Code__c", "Hours__c", "Fee_Amount__c", "Expense_Amount__c"], actions=[]),
     dict(api="Budget_Template__c", label="Budget Template", plural="Budget Templates", name=("Text", "Budget Template Name"),
          desc="Reusable budget lines by matter type.",
          fields=[pick("Type__c", "Matter Type", PRACTICE, gvs="Matter_Type"), check("Active__c", "Active", True), textarea("Description__c", "Description"),
                  lookup("UTBMS_Code_Set__c", "UTBMS Code Set", "UTBMS_Code_Set__c", "Budget_Templates", "Budget Templates")],
          sections=[("Budget Template", ["Name", "Type__c", "UTBMS_Code_Set__c"], ["Active__c", "Description__c"])],
          related=[("Budget_Template_Detail__c.Budget_Template__c", ["NAME", "UTBMS_Code__c", "Description__c", "Hours__c", "Fee_Amount__c", "Expense_Amount__c"])],
          list_cols=["NAME", "Type__c", "Active__c"], actions=[]),
     dict(api="Budget_Template_Detail__c", label="Budget Template Detail", plural="Budget Template Details",
          name=("AutoNumber", "Template Detail Number", "BTD-{00000}"), master=True, desc="One line of a budget template.",
          fields=[md("Budget_Template__c", "Budget Template", "Budget_Template__c", "Details", "Budget Template Details"),
                  lookup("UTBMS_Code__c", "UTBMS Code", "UTBMS_Code__c", "Budget_Template_Details", "Budget Template Details"),
                  text("Description__c", "Description"), num("Hours__c", "Hours", 8, 2),
                  money("Fee_Amount__c", "Fee Amount"), money("Expense_Amount__c", "Expense Amount")],
          sections=[("Template Detail", ["Name", "Budget_Template__c", "UTBMS_Code__c", "Description__c"], ["Hours__c", "Fee_Amount__c", "Expense_Amount__c"])],
          related=[], list_cols=["NAME", "Budget_Template__c", "UTBMS_Code__c", "Fee_Amount__c"], actions=[]),
     dict(api="UTBMS_Code_Set__c", label="UTBMS Code Set", plural="UTBMS Code Sets", name=("Text", "Code Set Name"),
          desc="A named set of UTBMS codes (for example LEDES Litigation).",
          fields=[textarea("Description__c", "Description"), check("Default__c", "Default"), check("Standard__c", "Standard (packaged)")],
          sections=[("Code Set", ["Name", "Description__c"], ["Default__c", "Standard__c"])],
          related=[("UTBMS_Code__c.UTBMS_Code_Set__c", ["NAME", "Code_Type__c", "Description__c", "Phase__c"])],
          list_cols=["NAME", "Default__c", "Standard__c"], actions=[]),
     dict(api="Skill_Certification__c", label="Skill & Certification", plural="Skills & Certifications",
          name=("Text", "Skill or Certification"), desc="Skills, bar admissions, languages and certifications of timekeepers and contacts.",
          fields=[lookup("Timekeeper__c", "Timekeeper", "Timekeeper__c", "Skills_Certifications", "Skills & Certifications"),
                  lookup("Contact__c", "Contact", "Contact", "Skills_Certifications", "Skills & Certifications"),
                  pick("Type__c", "Type", ["Skill", "Certification", "Bar Admission", "Language", "Education"]),
                  text("Issuing_Body__c", "Issuing Body"), text("Year_Text__c", "Year", 4), date("Expiration_Date__c", "Expiration Date")],
          sections=[("Skill & Certification", ["Name", "Type__c", "Issuing_Body__c", "Year_Text__c"], ["Timekeeper__c", "Contact__c", "Expiration_Date__c"])],
          related=[], list_cols=["NAME", "Type__c", "Timekeeper__c", "Contact__c", "Year_Text__c"], actions=[]),
     dict(api="Focus_Matter__c", label="Focus Matter", plural="Focus Matters", name=("AutoNumber", "Focus Matter Number", "FM-{000000}"),
          master=True, desc="A matter a user has pinned to their Focus Matters list.",
          fields=[md("Matter__c", "Matter", "Matter__c", "Focus_Matters", "Focus Matters"),
                  lookup("User__c", "User", "User", "Focus_Matters", "Focus Matters"),
                  text("Unique_Key__c", "Unique Key", 40, unique=True)],
          sections=[("Focus Matter", ["Name", "Matter__c"], ["User__c", "Unique_Key__c"])],
          related=[], list_cols=["NAME", "Matter__c", "User__c"], actions=[]),
     dict(api="Transaction__c", label="Transaction", plural="Transactions", name=("AutoNumber", "Transaction Number", "TRX-{0000000}"),
          desc="System-maintained union of estimates (budgets) and actuals (time, expenses, invoice lines) for reporting. Refreshed nightly.",
          fields=[lookup("Matter__c", "Matter", "Matter__c", "Transactions", "Transactions"),
                  lookup("Account__c", "Account", "Account", "Matter_Transactions", "Matter Transactions"),
                  lookup("Timekeeper__c", "Timekeeper", "Timekeeper__c", "Transactions", "Transactions"),
                  pick("Transaction_Type__c", "Transaction Type", ["Actual", "Estimate", "Billed"]),
                  pick("Source__c", "Source", ["Time", "Expense", "Budget", "Budget Detail", "Invoice Line Item", "Recurrence Transaction"]),
                  text("Source_Record_Id__c", "Source Record Id", 18, unique=True),
                  date("Transaction_Date__c", "Transaction Date"), num("Hours__c", "Hours", 8, 2),
                  money("Fee_Amount__c", "Fee Amount"), money("Expense_Amount__c", "Expense Amount"),
                  formula("Amount__c", "Amount", "Currency", "BLANKVALUE(Fee_Amount__c, 0) + BLANKVALUE(Expense_Amount__c, 0)"),
                  text("UTBMS_Code__c", "UTBMS Code", 20), text("Description__c", "Description")],
          sections=[("Transaction", ["Name", "Matter__c", "Account__c", "Timekeeper__c", "Transaction_Type__c", "Source__c", "Source_Record_Id__c"],
                     ["Transaction_Date__c", "Hours__c", "Fee_Amount__c", "Expense_Amount__c", "Amount__c", "UTBMS_Code__c", "Description__c"])],
          related=[], list_cols=["NAME", "Matter__c", "Transaction_Type__c", "Source__c", "Transaction_Date__c", "Amount__c"], actions=[]),
     dict(api="Recurrence_Transaction__c", label="Recurrence Transaction", plural="Recurrence Transactions",
          name=("AutoNumber", "Recurrence Number", "RCT-{00000}"), master=True,
          desc="A scheduled recurring fee (retainer or periodic fixed fee) generated from a matter fee arrangement.",
          fields=[md("Matter__c", "Matter", "Matter__c", "Recurrence_Transactions", "Recurrence Transactions"),
                  lookup("Matter_Fee_Arrangement__c", "Matter Fee Arrangement", "Matter_Fee_Arrangement__c", "Recurrence_Transactions", "Recurrence Transactions"),
                  lookup("Source_Fee_Arrangement__c", "Source Fee Arrangement", "Fee_Arrangement__c", "Recurrence_Transactions", "Recurrence Transactions"),
                  lookup("Account__c", "Account", "Account", "Recurrence_Transactions", "Recurrence Transactions"),
                  date("Transaction_Date__c", "Transaction Date"), money("Amount__c", "Amount"), text("Description__c", "Description"),
                  pick("Status__c", "Status", ["Unprocessed", "Billed"], "Unprocessed"),
                  lookup("Invoice__c", "Invoice", "Invoice__c", "Recurrence_Transactions", "Recurrence Transactions")],
          sections=[("Recurrence Transaction", ["Name", "Matter__c", "Matter_Fee_Arrangement__c", "Source_Fee_Arrangement__c", "Account__c"],
                     ["Transaction_Date__c", "Amount__c", "Description__c", "Status__c", "Invoice__c"])],
          related=[], list_cols=["NAME", "Matter__c", "Transaction_Date__c", "Amount__c", "Status__c"], actions=[]),
    ]
    OBJECTS.extend(new)
    by.update({o["api"]: o for o in new})

    # ---------- new fields on existing objects
    add("Intake__c", [pick("Matter_Record_Type__c", "Matter Record Type", ["General", "Litigation", "Personal_Injury", "Family_Law", "Transactional"], "General")])
    by["Intake__c"]["sections"][0][2].append("Matter_Record_Type__c")
    by["Intake__c"]["related"].append(("RelatedProcessHistoryList", None))
    by["Intake__c"]["actions"].append("Submit")

    add("Matter__c", [lookup("UTBMS_Code_Set__c", "UTBMS Code Set", "UTBMS_Code_Set__c", "Matters", "Matters")])
    by["Matter__c"]["sections"][1][2].append("UTBMS_Code_Set__c")
    for rl, cols in [("Offer_and_Demand__c.Matter__c", ["NAME", "Type__c", "Amount__c", "Date__c", "Status__c"]),
                     ("Comment__c.Matter__c", ["NAME", "Comment_Type__c", "Comment__c"]),
                     ("Cross_Reference_Matter__c.Matter__c", ["NAME", "Related_Matter__c", "Relationship__c"]),
                     ("Recurrence_Transaction__c.Matter__c", ["NAME", "Transaction_Date__c", "Amount__c", "Status__c"]),
                     ("Transaction__c.Matter__c", ["NAME", "Transaction_Type__c", "Source__c", "Transaction_Date__c", "Amount__c"])]:
        related("Matter__c", rl, cols)
    by["Matter__c"]["actions"] = ["Matter__c.Log_Time", "Matter__c.Apply_Activity_Plan", "Matter__c.Generate_Invoice", "Matter__c.Toggle_Focus_Matter",
                                  "Matter__c.Refresh_Transactions"]

    add("Budget__c", [
        rollup("Number_of_Budget_Details__c", "Number of Budget Details", "Budget_Detail__c", "Budget__c", "count", rtype="Number"),
        formula("Remaining_Budget__c", "Remaining Budget", "Currency",
                "BLANKVALUE(Fee_Budget__c,0) + BLANKVALUE(Expense_Budget__c,0) - (Matter__r.Total_Time_Value__c + Matter__r.Total_Expenses__c)"),
        formula("Total_Budget_Percentage_Remaining__c", "Total Budget % Remaining", "Percent",
                "IF(BLANKVALUE(Fee_Budget__c,0) + BLANKVALUE(Expense_Budget__c,0) > 0, 1 - (Matter__r.Total_Time_Value__c + Matter__r.Total_Expenses__c) / (BLANKVALUE(Fee_Budget__c,0) + BLANKVALUE(Expense_Budget__c,0)), 0)"),
        formula("Total_Fee_Percentage_Remaining__c", "Total Fee % Remaining", "Percent",
                "IF(BLANKVALUE(Fee_Budget__c,0) > 0, 1 - Matter__r.Total_Time_Value__c / Fee_Budget__c, 0)"),
        formula("Total_Expense_Percentage_Remaining__c", "Total Expense % Remaining", "Percent",
                "IF(BLANKVALUE(Expense_Budget__c,0) > 0, 1 - Matter__r.Total_Expenses__c / Expense_Budget__c, 0)"),
        lookup("Budget_Template__c", "Budget Template", "Budget_Template__c", "Budgets", "Budgets")],
        section=("Budget vs Actual", ["Remaining_Budget__c", "Total_Budget_Percentage_Remaining__c"],
                 ["Total_Fee_Percentage_Remaining__c", "Total_Expense_Percentage_Remaining__c", "Number_of_Budget_Details__c", "Budget_Template__c"]))
    related("Budget__c", "Budget_Detail__c.Budget__c", ["NAME", "UTBMS_Code__c", "Description__c", "Hours__c", "Fee_Amount__c", "Expense_Amount__c"])
    by["Budget__c"]["actions"] = ["Budget__c.Apply_Budget_Template"]

    add("UTBMS_Code__c", [lookup("UTBMS_Code_Set__c", "UTBMS Code Set", "UTBMS_Code_Set__c", "Codes", "UTBMS Codes"),
                          check("Standard__c", "Standard (packaged)")])
    by["UTBMS_Code__c"]["sections"][0][2].extend(["UTBMS_Code_Set__c", "Standard__c"])

    add("Activity_Plan_Template_Item__c", [
        lookup("Depends_On__c", "Depends On", "Activity_Plan_Template_Item__c", "Dependent_Items", "Dependent Items"),
        num("Days_After_Dependency__c", "Days After Dependency", 4, 0)])
    by["Activity_Plan_Template_Item__c"]["sections"][0][2].extend(["Depends_On__c", "Days_After_Dependency__c"])

    add("Timekeeper__c", [])
    related("Timekeeper__c", "Skill_Certification__c.Timekeeper__c", ["NAME", "Type__c", "Year_Text__c", "Expiration_Date__c"])
    related("Invoice__c", "Recurrence_Transaction__c.Invoice__c", ["NAME", "Transaction_Date__c", "Amount__c"])
    by["Matter_Legal_Hold_Acknowledgement__c"]["actions"] = ["Matter_Legal_Hold_Acknowledgement__c.Acknowledge"]

    # ---------- record types
    by["Participant__c"]["record_types"] = [("Account", "Account"), ("Contact", "Contact"), ("User", "Staff"), ("Other", "Other")]
    by["Matter__c"]["record_types"] = [("General", "General"), ("Litigation", "Litigation"), ("Personal_Injury", "Personal Injury"),
                                       ("Family_Law", "Family Law"), ("Transactional", "Transactional")]
    return new


# Fields on standard objects: (object, field dict)
def standard_fields(h):
    return [
        ("User", h["check"]("Create_Timekeeper__c", "Create Timekeeper")),
        ("Activity", h["num"]("Time_in_Hours__c", "Time in Hours", 5, 2)),
        ("Activity", h["text"]("Time_Record_Id__c", "Time Record Id", 18)),
        ("Activity", h["text"]("Activity_Plan_Id__c", "Activity Plan Id", 18)),
        ("Activity", h["text"]("Activity_Plan_Item_Id__c", "Activity Plan Item Id", 18)),
    ]


# Hierarchy custom setting
SETTINGS_FIELDS = [
    ("Disable_Matter_Trigger__c", "Disable Matter Trigger", "Checkbox"),
    ("Disable_Time_Trigger__c", "Disable Time Trigger", "Checkbox"),
    ("Disable_Expense_Trigger__c", "Disable Expense Trigger", "Checkbox"),
    ("Disable_Participant_Trigger__c", "Disable Participant Trigger", "Checkbox"),
    ("Disable_Activity_Trigger__c", "Disable Activity Trigger", "Checkbox"),
    ("Disable_Budget_Trigger__c", "Disable Budget Trigger", "Checkbox"),
    ("Disable_Rate_Trigger__c", "Disable Rate Trigger", "Checkbox"),
    ("Disable_Legal_Hold_Trigger__c", "Disable Legal Hold Trigger", "Checkbox"),
    ("Send_Legal_Hold_Emails__c", "Send Legal Hold Emails", "Checkbox"),
    ("Legal_Hold_Callback_Class__c", "Legal Hold Callback Class", "Text"),
]
