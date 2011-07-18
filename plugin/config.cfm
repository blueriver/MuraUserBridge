<!---
   Copyright 2011 Blue River Interactive

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--->
<cfsilent>
<cfif not structKeyExists(request,"pluginConfig")>
<cfset pluginID=listGetat(getDirectoryFromPath(getCurrentTemplatePath()),listLen(getDirectoryFromPath(getCurrentTemplatePath()),application.configBean.getFileDelim())-1,application.configBean.getFileDelim())>
<cfset request.pluginConfig=application.pluginManager.getConfig(pluginID)>
<cfset request.pluginConfig.setSetting("pluginMode","Admin")/>
</cfif>

<cfif request.pluginConfig.getSetting("pluginMode") eq "Admin" and not isUserInRole('S2')>
	<cfif not structKeyExists(session,"siteID") or (structKeyExists(session,"siteID") and not application.permUtility.getModulePerm(request.pluginConfig.getValue('moduleID'),session.siteid))>
		<cflocation url="#application.configBean.getContext()#/admin/" addtoken="false">
	</cfif>
</cfif>

<cfset cfcPath=request.pluginConfig.getPackage() & ".lib">
<cfset loginManager=createObject("component","#cfcPath#.loginManager").init(application.configBean,request.pluginConfig)>
</cfsilent>
