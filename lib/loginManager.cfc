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
<cfcomponent output="false" extends="mura.plugin.pluginGenericEventHandler">

<cffunction name="onApplicationLoad" access="public" output="false">
	<cfargument name="$">
	<cfset variables.pluginConfig.addEventHandler(this)>
</cffunction>

<cffunction name="login" access="public" output="false">
	<cfargument name="$">
	
	<cfset var rsGroups = "" />
	<cfset var userStruct = "" />
	<cfset var userBean = "" />
	<cfset var rsMemberships = "" />
	<cfset var rolelist="" />
	<cfset var adminGroup=variables.pluginConfig.getSetting('AdminGroup')/>
	<cfset var i="">
	<cfset var tempPassword=createUUID()>
	<cfset var siteID=$.event("siteID")>
	
	<cfif not len(siteID)>
		<cfif len(variables.pluginConfig.getSetting('defaultSiteID'))>
			<cfset siteID=variables.pluginConfig.getSetting('defaultSiteID')>
		<cfelse>	
			<cfset siteID=getSiteID()>
		</cfif>
		<cfset $.event('siteID',siteID)>
	</cfif>
	
	<cfset userStruct=lookUpUser($.event("username"),$.event("password"),$.event("externalLoginMode"))>
	
	<cfif userStruct.found>
					            
		<cfif len(userStruct.memberships) and variables.pluginConfig.getSetting('syncMemberships') eq "True">			
			<cfset rsGroups=application.userManager.getPublicGroups($.event('siteID')) />     
			<cfloop query="rsGroups">
				<cfif listFindNoCase(userStruct.memberships,rsGroups.groupname)>
					<cfset rolelist=listappend(rolelist,rsGroups.userID)>
				</cfif>
			</cfloop>
	                    
	        <cfset rsGroups=application.userManager.getPrivateGroups($.event('siteID')) />     
			<cfloop query="rsGroups">
	        	<cfif rsGroups.groupname eq "Admin">
					<cfif listFindNoCase(userStruct.memberships,adminGroup)>
						<cfset rolelist=listappend(rolelist,rsGroups.userID)>
					</cfif>
				<cfelseif listFindNoCase(userStruct.memberships,rsGroups.groupname)>
					<cfset rolelist=listappend(rolelist,rsGroups.userID)>
	            </cfif>
			</cfloop>
		</cfif>
		
		<cflock name="#$.event('siteID')##userStruct.remoteID#userBridge" timeout="30" type="exclusive">
			<!--- Check to see if the user has previous login into the system --->
			<cfset userBean=$.getBean('user').loadBy(username=userStruct.username,siteID=$.event('siteID'))>						
						
			<cfset userBean.set(userStruct) />
			<cfset userBean.setPassword(tempPassword) />
			<cfset userBean.setlastUpdateBy('System') />
						
			<cfif variables.pluginConfig.getSetting('syncMemberships') eq "True">					
				<cfset userBean.setGroupID(rolelist) />
			</cfif>
							
			<cfif len(variables.pluginConfig.getSetting('groupID'))>
				<cfset userBean.setGroupID(variables.pluginConfig.getSetting('groupID'),true) />
			</cfif>
						
			<cfif userBean.getIsNew()>
				<cfif variables.pluginConfig.getSetting('isPublic') eq "0">
					<cfset userBean.setSiteID($.siteConfig('PrivateUserPoolID'))/>
					<cfset userBean.setIsPublic(0)>
				<cfelse>
					<cfset userBean.setSiteID($.siteConfig('PublicUserPoolID')) />
					<cfset userBean.setIsPublic(1)>
				</cfif>
			</cfif>
						
			<cfset userBean.save()>				
		</cflock>
		<cfset $.event("username",userStruct.username)>
		<cfset $.event("password",tempPassword)>
	</cfif>
			
</cffunction>

<!--- This is a simple example 
<cffunction name="lookupUser" output="false">
<cfargument name="username">
<cfargument name="password">

<cfset var returnStruct=structNew()>

<!--- Do you custom logic to look up use in external user database.
Set the "returnStruct .success" variables. to true or false depending if the user was found.--->
<cfif arguments.username eq "John">
	<cfset returnStruct.found=true>
	<cfset returnStruct.fname= "John">
	<cfset returnStruct.lname= "Doe">
	<cfset returnStruct.username= "JohnDoe">
	<cfset returnStruct.remoteID= "JohnDoe">
	<cfset returnStruct.email= "john@example.com">
	<!--- The memberships attribute is a comma separated list of user groups or roles that this user  should be assigned (IE. "Sales,Member,Board of Directors")--->
	<cfset returnStruct.memberships="">
<cfelse>	

	<cfset returnStruct.found=false>
	<cfset returnStruct.fname= "">
	<cfset returnStruct.lname= "">
	<cfset returnStruct.username= "">
	<cfset returnStruct.email= "">
	<cfset returnStruct.memberships="">
</cfif>

<cfreturn returnStruct>
</cffunction>
--->

<cffunction name="lookupUser" access="public" output="false">
	<cfargument name="username">
	<cfargument name="password" default="">
	<cfargument name="mode" default="manual">
	
	<cfset var rsUser = "" />
	<cfset var returnStruct = structNew() />
	<cfset var found=false />
	<cfset var LDAP=structNew()>
	<cfset var i="">
	
	<cfset LDAP.Scope=variables.pluginConfig.getSetting('Scope')/>
	<!---<cfset LDAP.start=variables.pluginConfig.getSetting('start')/>--->		
	<cfset LDAP.server=variables.pluginConfig.getSetting('Server')/>
	<cfset LDAP.port=variables.pluginConfig.getSetting('Port')/>
	<cfset LDAP.FirstName=variables.pluginConfig.getSetting('FirstName')/>
	<cfset LDAP.LastName=variables.pluginConfig.getSetting('LastName')/>
	<cfset LDAP.delimiter=variables.pluginConfig.getSetting('UsernameSyntaxDelimeter')/>
	<cfset LDAP.Email=variables.pluginConfig.getSetting('email')/>
	<cfset LDAP.UID=variables.pluginConfig.getSetting('UID')/>
	<cfset LDAP.MemberOf=variables.pluginConfig.getSetting('MemberOf')/>
		
	<cfif structKeyExists(request,"userDomain") and len(request.userDomain)>
		<cfset LDAP.userDomain=request.userDomain>
	<cfelse>	
		<cfset LDAP.userDomain=listFirst(variables.pluginConfig.getSetting('userDomain'))/>
	</cfif>
		
	<!--- Dynamically set start based on userdomain for intel --->
	<cfset LDAP.start="">
	<cfloop from="1" to="#listLen(LDAP.userDomain,'.')#"index="i">
		<cfset LDAP.start=listAppend(LDAP.start,"DC=#listGetAt(LDAP.userDomain,i,'.')#")>
	</cfloop>
		
	<cfif isBoolean(variables.pluginConfig.getSetting('useSSL'))
			and variables.pluginConfig.getSetting('useSSL')>
		<cfset LDAP.secure="CFSSL_Basic">
	<cfelse>	
		<cfset LDAP.secure="">
	</cfif>
	
	<cfif arguments.mode eq "manual">
		<cfset LDAP.Username=variables.pluginConfig.getSetting('usernameSyntax')>
		<cfset LDAP.Username=replaceNoCase(LDAP.Username,"{uid}",arguments.username,"ALL")>
		<cfset LDAP.Username=replaceNoCase(LDAP.Username,"{delimiter}",LDAP.delimiter,"ALL")>
		<cfset LDAP.Username=replaceNoCase(LDAP.Username,"{userdomain}",LDAP.UserDomain,"ALL")>
		<cfset LDAP.password=arguments.password>
	<cfelse>
		<cfset LDAP.Username=variables.pluginConfig.getSetting('AutoLoginUsername')>
		<cfset LDAP.password=variables.pluginConfig.getSetting('AutoLoginPassword')>
	</cfif>
	
	<!--- Get User --->
	<cftry>
		<cfldap action="QUERY"
			name="rsUser"
			attributes="dn,#LDAP.FirstName#,#LDAP.LastName#,#LDAP.Email#,#LDAP.MemberOf#"
			start="#LDAP.start#"
			maxrows="1"
			scope="#LDAP.Scope#"
			filter="#LDAP.uid#=#arguments.username#"
			server="#LDAP.server#"
			port="#LDAP.port#"
			username="#LDAP.Username#"
			password="#LDAP.password#"
			>
			<!--- 
			Removed LDAP secure attribute because it's not supported by Railo yet
			secure="#LDAP.Secure#" --->
			<cfset found=true>

				
	<cfcatch type="any">
		<cfif variables.pluginConfig.getSetting('debugging') eq "True">
		<cfdump var="#cfcatch#">
		<cfabort>
		</cfif>
	</cfcatch>
	</cftry>

	<cfif found and rsUser.recordcount>
	
		<cfset returnStruct.found=true />
		<cfset returnStruct.remoteID=LDAP.Username />
		<cfset returnStruct.username=arguments.username />
		<cfset returnStruct.fname=evaluate("rsUser.#LDAP.FirstName#") />
		<cfset returnStruct.lname=evaluate("rsUser.#LDAP.LastName#") />
		<cfset returnStruct.email=evaluate("rsUser.#LDAP.email#") />
		
		<cfif not len(returnStruct.email)>
			<cfset  returnStruct.email=arguments.username & '@' & LDAP.server>
		</cfif>
		
		<cfset returnStruct.memberships="">
			            
		<cfif variables.pluginConfig.getSetting('syncMemberships') eq "True">			
			<cfloop list="#rsUser.memberof#" index="i">
			<cfif trim(listFirst(i,"=")) eq "CN">
				<cfset returnStruct.memberships=listappend(returnStruct.memberships,listLast(i,"="))>
			</cfif>
			</cfloop>
		</cfif>
		
	<cfelse>
		<cfset returnStruct.found=false />
		<cfset returnStruct.remoteID="" />
		<cfset returnStruct.username=""/>
		<cfset returnStruct.fname="" />
		<cfset returnStruct.lname="" />
		<cfset returnStruct.email="" />
		<cfset returnStruct.memberships="">
	</cfif>
	
	<cfreturn returnStruct>
								  			
</cffunction>


<cffunction name="getSiteID" output="false" returntype="string">
		<cfset var siteID="">
		<cfset var rsSites=application.settingsManager.getList(sortBy="orderno") />

		<!--- check for exact host match to find siteID --->
		<cfloop query="rsSites">
			<cftry>
			<cfif cgi.SERVER_NAME eq application.settingsManager.getSite(rsSites.siteID).getDomain()>
			<cfset siteID = rsSites.siteID />
			<cfbreak/>
			</cfif>
			<cfcatch></cfcatch>
			</cftry>
		</cfloop>
		
		<cfif not len(siteID)>
			<cfloop query="rssites">
			<cftry>
			<cfif find(cgi.SERVER_NAME,application.settingsManager.getSite(rsSites.siteID).getDomain())>
				<cfset siteID = rsSites.siteID />
				<cfbreak/>
			</cfif>
			<cfcatch></cfcatch>
			</cftry>
			</cfloop>
		</cfif>
		
		<cfif not len(siteID)>
			<cfset siteID = rsSites.siteID />
		</cfif>		
		
		<cfreturn siteid>
</cffunction>

<cffunction name="onSiteRequestStart">
	<cfargument name="$">
	<cfset var username="">
	
	<cfif variables.pluginConfig.getSetting('mode') eq "Automatic" 
		and variables.pluginConfig.getSetting('where') eq 'Site'
		and not $.currentUser().getIsLoggedIn()
		and len(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))>
		
		<cftry>
			<cfset username=evaluate(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))>
		<cfcatch></cfcatch>
		</cftry>
		
		<cfif len(username)>
			<cfset $.event("username",username)>	
			<cfset $.event("externalLoginMode","auto")>	
			<cfset login($)/>
		</cfif>				
	</cfif> 
</cffunction>

<cffunction name="onGlobalRequestStart">
	<cfargument name="$">
	<cfset var username="">
	
	<cfif variables.pluginConfig.getSetting('mode') eq "Automatic" 
		and variables.pluginConfig.getSetting('where') eq 'Global'
		and not $.currentUser().getIsLoggedIn()
		and len(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))>
		
		<cftry>
		<cfset username=evaluate(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))>
		<cfcatch></cfcatch>
		</cftry>
		
		<cfif len(username)>
			<cfset $.event("username",username)>	
			<cfset $.event("externalLoginMode","auto")>	
			<cfset login($)/>
		</cfif>			
	</cfif> 
</cffunction>

<cffunction name="onSiteLogin">
	<cfargument name="$">
	<cfset var mode=variables.pluginConfig.getSetting('mode')>
	<cfif mode eq "Manual" or not len(mode)>
		<cfset $.event("externalLoginMode","manual")>
		<cfset login($)>
	</cfif> 
</cffunction>

<cffunction name="onGlobalLogin">
	<cfargument name="$">
	<cfset var mode=variables.pluginConfig.getSetting('mode')>
	<cfif (mode eq "Manual" or not len(mode))
	and variables.pluginConfig.getSetting('where') eq "global">
		<cfset $.event("externalLoginMode","manual")>
		<cfset login($) />
	</cfif>  
</cffunction>

</cfcomponent>
