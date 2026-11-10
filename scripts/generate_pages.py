#!/usr/bin/env python3
"""Generate Lightning pages: Matter record page, Matter Management home page and the app pages behind custom tabs."""
import os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "force-app", "main", "default", "flexipages")
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'

def comp(name, ident, props=None):
    p = "".join(f"<componentInstanceProperties><name>{k}</name><value>{v}</value></componentInstanceProperties>" for k, v in (props or {}).items())
    return f"<itemInstances><componentInstance>{p}<componentName>{name}</componentName><identifier>{ident}</identifier></componentInstance></itemInstances>"

def region(name, items, kind="Region"):
    return f"<flexiPageRegions>{''.join(items)}<name>{name}</name><type>{kind}</type></flexiPageRegions>"

def tab(ident, body, title, active=False):
    props = {"active": "true"} if active else {}
    props.update({"body": body, "title": title})
    return comp("flexipage:tab", ident, props)

def page(name, label, template, kind, regions, sobject=None):
    so = f"<sobjectType>{sobject}</sobjectType>" if sobject else ""
    parent = ""
    xml = (f'<?xml version="1.0" encoding="UTF-8"?>\n<FlexiPage {NS}>{"".join(regions)}<masterLabel>{label}</masterLabel>'
           f"{parent}{so}<template><name>{template}</name></template><type>{kind}</type></FlexiPage>\n")
    os.makedirs(ROOT, exist_ok=True)
    open(os.path.join(ROOT, f"{name}.flexipage-meta.xml"), "w").write(xml)

# Matter record page
page("Matter_Record_Page", "Matter Record Page", "flexipage:recordHomeTemplateDesktop", "RecordPage", [
    region("header", [comp("force:highlightsPanel", "highlights", {"collapsed": "false", "numVisibleActions": "5"})]),
    region("detailTabContent", [comp("force:detailPanel", "detail")], "Facet"),
    region("relatedTabContent", [comp("force:relatedListContainer", "related", {"relatedListComponentOverride": "NONE", "rowsToDisplay": "10", "showActionBar": "true"})], "Facet"),
    region("timelineTabContent", [comp("matterTimeline", "matterTimeline")], "Facet"),
    region("billingTabContent", [comp("billingPreview", "billingPreview")], "Facet"),
    region("settlementTabContent", [comp("settlementCalculator", "settlementCalculator")], "Facet"),
    region("maintabs", [tab("detailTab", "detailTabContent", "Standard.Tab.detail", True),
                        tab("relatedTab", "relatedTabContent", "Standard.Tab.relatedLists"),
                        tab("timelineTab", "timelineTabContent", "Timeline"),
                        tab("billingTab", "billingTabContent", "Billing Preview"),
                        tab("settlementTab", "settlementTabContent", "Settlement")], "Facet"),
    region("main", [comp("flexipage:tabset", "mainTabset", {"tabs": "maintabs"})]),
    region("activityTabContent", [comp("runtime_sales_activities:activityPanel", "activityPanel")], "Facet"),
    region("sidebartabs", [tab("activityTab", "activityTabContent", "Standard.Tab.activity", True)], "Facet"),
    region("sidebar", [comp("taskChecklist", "taskChecklist"), comp("flexipage:tabset", "sideTabset", {"tabs": "sidebartabs"})]),
], sobject="Matter__c")

# Home page for the Matter Management app
page("Matter_Management_Home", "Matter Management Home", "home:desktopTemplate", "HomePage", [
    region("top", [comp("focusMatters", "focusMatters")]),
    region("bottomLeft", [comp("runtime_sales_activities:todayTaskContainer", "todayTasks")]),
    region("bottomRight", [comp("home:recentRecordContainer", "recentRecords")]),
    region("sidebar", [comp("dateCalculator", "dateCalculator"), comp("runtime_approval_process:pendingApprovalCard", "pendingApprovals")]),
])

# App pages behind custom tabs
for name, label, comps in [("Billing_Preview_Page", "Billing Preview", ["billingPreview"]),
                           ("Batch_Time_Page", "Batch Time", ["batchTime"]),
                           ("Batch_Conflict_Check_Page", "Batch Conflict Check", ["batchConflictCheck"]),
                           ("Legal_Tools_Page", "Legal Tools", ["focusMatters", "dateCalculator"])]:
    page(name, label, "flexipage:defaultAppHomeTemplate", "AppPage", [region("main", [comp(c, c) for c in comps])])
print("pages written")
