// SafeText Main JS Startup File

(function() {
	
	// Create the Safetext namespace
	if (typeof Safetext == 'undefined') {
		window["Safetext"] = {};	// global Object container to create namespace
	}
	
	
	/**
	 *	Cookie Handling
	 */
	function setCookie(c_name, value, exdays) {
	    var exdate = new Date();
	    exdate.setDate(exdate.getDate() + exdays);
	    var c_value = escape(value) + ((exdays == null) ? "" : "; expires=" + exdate.toUTCString());
	    document.cookie = c_name + "=" + c_value  + '; path=/;';
	    
	}
	
	function getCookie(c_name) {
	    var i, x, y, ARRcookies = document.cookie.split(";");
	    for (i = 0; i < ARRcookies.length; i++) {
	        x = ARRcookies[i].substr(0, ARRcookies[i].indexOf("="));
	        y = ARRcookies[i].substr(ARRcookies[i].indexOf("=") + 1);
	        x = x.replace(/^\s+|\s+$/g, "");
	        if (x == c_name) {
	            return unescape(y);
	        }
	    }
	}
	
	
	/**
	 * MsPageManager
	 * Object to dynamically load JS and CSS files at run-time (i.e. after Ajax calls)
	 */
	function MsPageManager() {
		this.filesAdded = '' // list of files already added. Tracked so we avoid adding duplicate files to the DOM
	}
	
	MsPageManager.prototype.addCss = function(filepath) {
		if (this.filesAdded.indexOf("[" + filepath + "]") == -1) { // file not added yet
//			console.log('Adding CSS File: ' + filepath);
			var fileref = document.createElement('link');
			fileref.setAttribute("rel", "stylesheet");
			fileref.setAttribute("type", "text/css");
			fileref.setAttribute("href", filepath);
			
			// put in file added list
			this.filesAdded += "[" + filepath + "]";
			
			// add to DOM
			if (typeof fileref != "undefined")
				document.getElementsByTagName("head")[0].appendChild(fileref);
		}
	};
	MsPageManager.prototype.addJs = function(filepath) {
		if (this.filesAdded.indexOf("[" + filepath + "]") == -1) { // file not added yet
//			console.log('Adding JS File: ' + filepath);
			var fileref = document.createElement('script');
			fileref.setAttribute("type", "text/javascript");
			fileref.setAttribute("src", filepath);
			
			// put in file added list
			this.filesAdded += "[" + filepath + "]";
			
			// add to DOM
			if (typeof fileref != "undefined")
				document.getElementsByTagName("head")[0].appendChild(fileref);
		}
	};
	
	/**
	 * Tasks to run at every page change
	 * @param $("div") page
	 */
	MsPageManager.prototype.pageChange = function(page) {
		// Load any page-specific JS file
		if (typeof(page.attr("data-safetext-load-js")) != "undefined") Safetext.pageManager.addJs("/assets/js/" + page.attr("data-safetext-load-js"));

		// If this is a conversation page, scroll to bottom automatically when page is loaded
		if (page.hasClass("safetext-conversation")) window.scrollTo(0,document.body.scrollHeight);
		
	};
	
	
	
	// ********* Hook Listeners to UI objects/events **********
	
	/**
	 * This function will run every time a page change occurs.
	 * 
	 */
	$(document).on( "pagecontainerhide", function( event, ui ) {
		Safetext.lastPage = ui.nextPage;	
		Safetext.pageManager.pageChange(ui.nextPage);
	});
	
	/**
	 * Log In.
	 * This event will run when the login form's Login button is clicked.
	 * Authenticates and logs a user into Safetext.
	 */
	$(document).on('click', '.safetext-login .safetext-login-button', function() {
		var thisForm = $(".safetext-login-form").filter(":visible");
		if (thisForm.find('input[name="name"]').val() == '') {
			alert("Enter your account name"); 
			return false;
		}
		if (thisForm.find('input[name="password"]').val() == '') {
			alert("Enter your password"); 
			return false;
		}

			
		$.ajax({url: '/api/auth',
			data: 'device_signature=webclient&device_description=Web+Client',
			headers: {'x-safetext-username': thisForm.find('input[name="name"]').val(),'x-safetext-password': thisForm.find('input[name="password"]').val()},
			type: 'post',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					//console.log('Token: ' + result.data.token);
					
					// set the auth cookie
					setCookie('token',result.data.token,7);
					
					// Go to dashboard
					window.location='/webclient/messages';
					
					
				} else {
					alert('Unable to login. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		}); 
		
		return false;
	});
	
	
	/**
	 * Register.
	 * This event will run when the registration form's Register button is clicked.
	 * Registers a new user.
	 */
	$(document).on('click', '.safetext-register .safetext-register-button', function() {
		var thisForm = $(".safetext-register-form").filter(":visible");
	
		if (thisForm.find('input[name="name"]').val() == '') {
			alert("Your name is required"); 
			return false;
		}
		if (thisForm.find('input[name="username"]').val() == '') {
			alert("Please select a username"); 
			return false;
		}
		if (thisForm.find('input[name="password"]').val() == '') {
			alert("Please select a password"); 
			return false;
		}
	
		$.ajax({url: '/api/users',
			data: 'device_signature=webclient&device_description=Web+Client&name=' + encodeURIComponent(thisForm.find('input[name="name"]').val()) + '&email=' + thisForm.find('input[name="email"]').val(),
			headers: {'x-safetext-username': thisForm.find('input[name="username"]').val(),'x-safetext-password': thisForm.find('input[name="password"]').val()},
			type: 'post',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					//console.log('Token: ' + result.data.token);
					
					// set the auth cookie
					setCookie('token',result.data.token,7);
					
					// Go to dashboard
					window.location='/webclient/messages';
					
				} else {
					alert('Unable to register. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		}); 
		
		return false;
	});
	
	
	/**
	 * New Message.
	 * This event will run when the new message composer's Send button is clicked
	 * Submits a new message to a contact.
	 */
	$(document).on('click', '.safetext-conversation .safetext-new-message-button', function() {
		var messageWindow = Safetext.lastPage.find(".safetext-new-message");
		if (messageWindow.val() != '') {
			var contactId = 	messageWindow.attr('data-safetext-contact');
			var messageText = 	messageWindow.val();
			var isDraft = 		messageWindow.attr('data-safetext-isdraft');
			var isImportant =	messageWindow.attr('data-safetext-isimportant');
			var lifetime = 		messageWindow.attr('data-safetext-lifetime');
			
			if (contactId > 0) {
				// call web service to send message
				$.ajax({url: '/api/messages',
					data: {
						"recipients": [contactId],
						"content": messageText,
						"is_important": isImportant,
						"is_draft": isDraft,
						"lifetime": lifetime
					},
					headers: {'x-safetext-token': getCookie('token')},
					type: 'post',               
					async: 'true',
					dataType: 'json',
					beforeSend: function() {
						// This callback function will trigger before data is sent
						$.mobile.loading( 'show');
					},
					complete: function() {
						// This callback function will trigger on data sent/received complete
						$.mobile.loading( "hide" );
					},
					success: function (result) {
						if(result.status === 'success') {
							// set the auth cookie
							if (typeof result.token != 'undefined') setCookie('token',result.token,7);
							
							if (isDraft != '1') {
								/** add new chat entry **/
								// generate the new listing content
								var entryContent = Safetext.lastPage.find(".kit-new-message-content");
								entryContent.find(".bubble").html(messageText); // update text
		 				
								// add as a new listing
								Safetext.lastPage.find(".safetext-chat-container").append(entryContent.html());
								
								// increment sent counter
								var sentCount = parseInt(Safetext.lastPage.find(".safetext-sent-counter").html());
								sentCount++;
								$(".safetext-sent-counter").text(sentCount);
							} else {
								// if this is a draft, increment draft counter
								var draftCount = parseInt(Safetext.lastPage.find(".safetext-drafts-counter").html());
								draftCount++;
								$(".safetext-drafts-counter").text(draftCount);
							}
							
							// scroll to bottom of page
							window.scrollTo(0,document.body.scrollHeight);
							
						} else {
							alert('Unable to send. The server said: ' + result.data.message); 
						}
					},
					error: function (request,error) {
						// This callback function will trigger on unsuccessful action                
						alert('Network error has occurred; please try again.');
					}
				});
				
				
				
	
				messageWindow.val(""); // clear message window for next message
			}
		}
		
		return false;
	});


	/**
	 * View Message Settings.
	 * This event will run when the new message settings button is clicked
	 * Opens the settings popup.
	 */
	$(document).on('click', '.safetext-conversation .safetext-message-settings-button', function() {	
		// open the picker in a pop-up
		Safetext.lastPage.find(".safetext-message-settings-popup").popup( "open");
	
		return false;
	});
	
	
	/**
	 * Apply Message Settings.
	 * This event will run when the new message settings Apply button is clicked
	 * Applies setting changes.
	 */
	$(document).on('click', '.safetext-conversation .safetext-message-settings-apply-button', function() {	
		// get form values
		var isDraft = '0';
		var isImportant = '0';
		var thisForm = Safetext.lastPage.find(".safetext-message-settings-form");
		if (thisForm.find('input[name="isdraft"]').is(":checked")) isDraft = '1';
		if (thisForm.find('input[name="isimportant"]').is(":checked")) isImportant = '1';
		var lifetime = thisForm.find('input[name="lifetime"]').val();
	
		if (parseInt(lifetime) < 1) lifetime = '1';
		if (parseInt(lifetime) <= 24) {
			thisForm.find('input[name="lifetime"]').val(lifetime);
			
			// set the attributes
			var messageWindow = Safetext.lastPage.find(".safetext-new-message");
			messageWindow.attr('data-safetext-isdraft', isDraft);
			messageWindow.attr('data-safetext-isimportant', isImportant);
			messageWindow.attr('data-safetext-lifetime', lifetime);
	
			// close the settings menu popup
			Safetext.lastPage.find(".safetext-message-settings-popup").popup( "close");
		} else {
			alert('Message time to expire cannot exceed 24 hours');
			thisForm.find('input[name="lifetime"]').val("24");
		}
	
		return false;
	});
	
	
	/**
	 * Save Contact.
	 * This event will run when a save contact button is clicked.
	 * Updates the on-server contact record with details from the current contact form.
	 */
	$(document).on('click', '.safetext-save-contact-button', function() {	
		var thisForm = Safetext.lastPage.find(".safetext-edit-contact-form");
		
		if (thisForm.find('input[name="name"]').val() != '') {
			$.ajax({url: '/api/contact',
				data: thisForm.serialize(),
				headers: {'x-safetext-token': getCookie('token')},
				type: 'post',               
				async: 'true',
				dataType: 'json',
				beforeSend: function() {
					// This callback function will trigger before data is sent
					$.mobile.loading( 'show');
				},
				complete: function() {
					// This callback function will trigger on data sent/received complete
					$.mobile.loading( "hide" );
				},
				success: function (result) {
					if(result.status === 'success') {
						// set the auth cookie
						if (typeof result.token != 'undefined') setCookie('token',result.token,7);
						
						// go back to contacts page
						$.mobile.pageContainer.pagecontainer("change", '/webclient/contacts/',{
							reloadPage : true
						});
						
					} else {
						alert('Unable to save changes. The server said: ' + result.data.message); 
					}
				},
				error: function (request,error) {
					// This callback function will trigger on unsuccessful action                
					alert('Network error has occurred; please try again.');
				}
			}); 


		
		} else {
			alert('Enter a name for this contact');
		}
	
		return false;
	});
	
	
	/**
	 * Remove Contact.
	 * This event will run when a contact record's Remove Contact button is clicked.
	 * Removes the on-server contact record for this user.
	 */
	$(document).on('click', '.safetext-contact .safetext-remove-contact-button', function() {	
		// get the contact ID
		var thisButton = Safetext.lastPage.find(".safetext-remove-contact-button");
		var contact = thisButton.attr('data-safetext-contact');

		// send remove request to server
		$.ajax({url: '/api/contact/contact/' + contact,
			headers: {'x-safetext-token': getCookie('token')},
			type: 'delete',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					// set the auth cookie
					if (typeof result.token != 'undefined') setCookie('token',result.token,7);
					
					// go back to contacts page
					$.mobile.pageContainer.pagecontainer("change", '/webclient/contacts/',{
						reloadPage : true
					});
					
					return true;
				} else {
					alert('Unable to remove contact. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		}); 

		return false;
	});
	
	
	/**
	 * Add Contact.
	 * This event will run when a search result for a new contact is clicked.
	 * Adds the search result as a new contact.
	 */
	$(document).on('click', '.safetext-contactadd .safetext-add-contact-record', function(event) {	

		var entry = $(event.target).closest("li");
		var name = entry.attr("data-safetext-name");
		var id = entry.attr("data-safetext-id");
		var phone = entry.attr("data-safetext-phone");
		var email = entry.attr("data-safetext-email");
		
		if (parseInt(id) > 0) {
			$.ajax({url: '/api/contact',
				data: {"contact": id, "name": name, "phone": phone, "email": email, "whitelist": '0', "blocked": '0'},
				headers: {'x-safetext-token': getCookie('token')},
				type: 'post',               
				async: 'true',
				dataType: 'json',
				beforeSend: function() {
					// This callback function will trigger before data is sent
					$.mobile.loading( 'show');
				},
				complete: function() {
					// This callback function will trigger on data sent/received complete
					$.mobile.loading( "hide" );
				},
				success: function (result) {
					if(result.status === 'success') {
						// set the auth cookie
						if (typeof result.token != 'undefined') setCookie('token',result.token,7);
						
						// go back to contacts page
						$.mobile.pageContainer.pagecontainer("change", '/webclient/contactadd',{
							reloadPage : true,
							allowSamePageTransition: true
						});
						
					} else {
						alert('Unable to add contact. The server said: ' + result.data.message); 
					}
				},
				error: function (request,error) {
					// This callback function will trigger on unsuccessful action                
					alert('Network error has occurred; please try again.');
				}
			}); 


		
		} else {
			alert('Bad Contact Id');
		}
	
		return false;
	});
	
	
	/**
	 * Confirm Message Delete.
	 * This event will run when a message's delete button is clicked.
	 * Opens the confirm delete messsage popup, sets the message ID reference.
	 */
	$(document).on('click', '.safetext-messages .safetext-delete-button', function(event) {	
		// open the confirmation dialog as a pop-up
		Safetext.lastPage.find(".safetext-confirm-delete-popup").popup( "open");
	
		// set reference to clicked event's ID
		var entry = $(event.target);
		var messageId = entry.attr('data-safetext-message-id');
		Safetext.lastPage.find(".safetext-confirm-delete-button").attr('data-safetext-deletemessage-id', messageId);

		return false;
	});
	
	
	/**
	 * Delete Message.
	 * This event will run when a message's confirm delete dialog's "Delete" button is clicked.
	 * Deletes message at server and sync's the update to all participants' devices.
	 */
	$(document).on('click', '.safetext-messages .safetext-confirm-delete-button', function(event) {	
		// get reference to target event's ID
		var dialog = $(event.target);
		var messageId = dialog.attr('data-safetext-deletemessage-id');

		// send delete request to server
		$.ajax({url: '/api/message/message/' + messageId,
			headers: {'x-safetext-token': getCookie('token')},
			type: 'delete',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					// set the auth cookie
					if (typeof result.token != 'undefined') setCookie('token',result.token,7);
					
					// close pop-up
					Safetext.lastPage.find(".safetext-confirm-delete-popup").popup( "close");
		
					// refresh page
					$.mobile.pageContainer.pagecontainer("change", window.location.href,{
						allowSamePageTransition : true,
						transition              : 'none',
						showLoadMsg             : false,
						reloadPage              : true
					});
					
					return true;
				} else {
					alert('Unable to delete message. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		});

		return false;
	});
	
	
	/**
	 * Edit Draft.
	 * This event will run when a draft message's edit button is clicked.
	 * Opens the edit draft menu, sets the message ID reference.
	 */
	$(document).on('click', '.safetext-messages .safetext-editdraft-button', function(event) {	
		// open the edit draft menu as a pop-up
		Safetext.lastPage.find(".safetext-editdraft-menu").popup( "open");
	
		// set references to clicked event's ID
		var entry = $(event.target);
		var messageId = entry.attr('data-safetext-message-id');
		Safetext.lastPage.find(".safetext-confirm-delete-button").attr('data-safetext-deletemessage-id', messageId);
		Safetext.lastPage.find(".safetext-send-draft-button").attr('data-safetext-sendmessage-id', messageId);

		return false;
	});
	
	
	/**
	 * Send Draft.
	 * This event will run when the "Send" entry of a draft message's edit menu is clicked.
	 * Sets is_draft to '0' for this message at server, effectively sending it, and sync's the update to all participants' devices.
	 */
	$(document).on('click', '.safetext-messages .safetext-send-draft-button', function(event) {	
		// get reference to target event's ID
		var dialog = $(event.target);
		var messageId = dialog.attr('data-safetext-sendmessage-id');

		// send delete request to server
		$.ajax({url: '/api/message/message/' + messageId,
			headers: {'x-safetext-token': getCookie('token')},
			type: 'post',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					// set the auth cookie
					if (typeof result.token != 'undefined') setCookie('token',result.token,7);
					
					// close pop-up
					Safetext.lastPage.find(".safetext-editdraft-menu").popup( "close");
		
					// refresh page
					$.mobile.pageContainer.pagecontainer("change", window.location.href,{
						allowSamePageTransition : true,
						transition              : 'none',
						showLoadMsg             : false,
						reloadPage              : true
					});
					
					return true;
				} else {
					alert('Unable to send message. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		});

		return false;
	});
	
	
	/**
	 * Apply Settings Update.
	 * This event will run when the settings menu's "Apply" buttin is clicked.
	 * Updates settings at the server.
	 */
	$(document).on('click', '.safetext-settings .safetext-apply-button', function(event) {	
		var thisForm = Safetext.lastPage.find(".safetext-settings-form");
		
		if (thisForm.find('input[name="username"]').val() != '') {
			$.ajax({url: '/api/settings',
				data: thisForm.serialize(),
				headers: {'x-safetext-token': getCookie('token')},
				type: 'post',               
				async: 'true',
				dataType: 'json',
				beforeSend: function() {
					// This callback function will trigger before data is sent
					$.mobile.loading( 'show');
				},
				complete: function() {
					// This callback function will trigger on data sent/received complete
					$.mobile.loading( "hide" );
				},
				success: function (result) {
					if(result.status === 'success') {
						// set the auth cookie
						if (typeof result.token != 'undefined') setCookie('token',result.token,7);
						
						// refresh page
						$.mobile.pageContainer.pagecontainer("change", window.location.href,{
							allowSamePageTransition : true,
							transition              : 'none',
							showLoadMsg             : false,
							reloadPage              : true
						});
						
					} else {
						alert('Unable to apply changes. The server said: ' + result.data.message); 
					}
				},
				error: function (request,error) {
					// This callback function will trigger on unsuccessful action                
					alert('Network error has occurred; please try again.');
				}
			}); 

		
		} else {
			alert('Your username can\'t be empty');
		}
	
		return false;
	});
	
	
	/**
	 * Confirm Unregister Device.
	 * This event will run when a message entry's delete button is clicked on the Settings page.
	 * Opens the confirm unregister device popup, sets the device ID reference.
	 */
	$(document).on('click', '.safetext-settings .safetext-delete-button', function(event) {	
		// open the confirmation dialog as a pop-up
		Safetext.lastPage.find(".safetext-confirm-delete-popup").popup( "open");
	
		// set reference to clicked event's ID
		var entry = $(event.target).closest("li");
		var deviceToken = entry.attr('data-safetext-device-token');
		Safetext.lastPage.find(".safetext-confirm-delete-button").attr('data-safetext-deletedevice-token', deviceToken);

		return false;
	});
	
	
	/**
	 * Unregister Device.
	 * This event will run when the confirm unregister device's Unregister button is clicked.
	 * Unregisters the referenced device at the server.
	 */
	$(document).on('click', '.safetext-settings .safetext-confirm-delete-button', function(event) {	
		var deviceToken = $(event.target).attr('data-safetext-deletedevice-token');
		
		if (deviceToken != '') {
			$.ajax({url: '/api/devices',
				headers: {'x-safetext-token': deviceToken},
				type: 'delete',               
				async: 'true',
				dataType: 'json',
				beforeSend: function() {
					// This callback function will trigger before data is sent
					$.mobile.loading( 'show');
				},
				complete: function() {
					// This callback function will trigger on data sent/received complete
					$.mobile.loading( "hide" );
				},
				success: function (result) {
					if(result.status === 'success') {
						// close confirmation popup
						Safetext.lastPage.find(".safetext-confirm-delete-popup").popup( "close");
						
						// refresh page
						$.mobile.pageContainer.pagecontainer("change", window.location.href,{
							allowSamePageTransition : true,
							transition              : 'none',
							showLoadMsg             : false,
							reloadPage              : true
						});
						
					} else {
						alert('Unable to unregister that device. The server said: ' + result.data.message); 
					}
				},
				error: function (request,error) {
					// This callback function will trigger on unsuccessful action                
					alert('Network error has occurred; please try again.');
				}
			}); 

		
		} else {
			Safetext.lastPage.find(".safetext-confirm-delete-popup").popup( "close");
			alert('There was a problem trying to obtain the device token to unregister it. Please try again.');
		}
	
		return false;
	});
	
	
	/**
	 * Subscription Options.
	 * This event will run when the settings page subscription status entry is clicked.
	 * Opens the subscription options menu.
	 */
	$(document).on('click', '.safetext-settings .safetext-membership-options-button', function(event) {	
		// open the edit draft menu as a pop-up
		Safetext.lastPage.find(".safetext-subscription-options-menu").popup( "open");
	
		return false;
	});
	
	
	/**
	 * Subscribe.
	 * This event will run when the subscription page's subscribe/extend button is clicked.
	 * Sends the purchase request to the server.
	 */
	$(document).on('click', '.safetext-subscribe .safetext-subscribe-button', function(event) {	
		// get the form details
		var thisForm = Safetext.lastPage.find(".safetext-subscribe-form");
		
		if (thisForm.find('input[name="subscriptionlevel"]').val() != '') {
			$.ajax({url: '/settings/processpayment',
				data: thisForm.serialize(),
				headers: {'x-safetext-token': getCookie('token')},
				type: 'post',               
				async: 'true',
				dataType: 'json',
				beforeSend: function() {
					// This callback function will trigger before data is sent
					$.mobile.loading( 'show');
				},
				complete: function() {
					// This callback function will trigger on data sent/received complete
					$.mobile.loading( "hide" );
				},
				success: function (result) {
					if(result.status === 'success') {
						// set the auth cookie
						if (typeof result.token != 'undefined') setCookie('token',result.token,7);
						
						// go back to settings page, refresh
						$.mobile.pageContainer.pagecontainer("change", '/settings',{
							transition              : 'none',
							reloadPage              : true
						});
						
					} else {
						alert('Unable to process payment. The server said: ' + result.data.message); 
					}
				},
				error: function (request,error) {
					// This callback function will trigger on unsuccessful action                
					alert('Network error has occurred; please try again.');
				}
			}); 

		
		} else {
			alert('A membership level must be selected');
		}
	
		return false;
	});
	
	
	/**
	 * Update Card.
	 * This event will run when the update card page's Apply button is clicked.
	 * Sends the update request to the server.
	 */
	$(document).on('click', '.safetext-card .safetext-update-button', function(event) {	
		// get the form details
		var thisForm = Safetext.lastPage.find(".safetext-update-form");
		
		if (thisForm.find('input[name="name"]').val() != '') {
			if (thisForm.find('input[name="cc_number"]').val() != '') {
				if (thisForm.find('input[name="cc_cvv2"]').val() != '') {
			
					$.ajax({url: '/settings/updatecard',
						data: thisForm.serialize(),
						headers: {'x-safetext-token': getCookie('token')},
						type: 'post',               
						async: 'true',
						dataType: 'json',
						beforeSend: function() {
							// This callback function will trigger before data is sent
							$.mobile.loading( 'show');
						},
						complete: function() {
							// This callback function will trigger on data sent/received complete
							$.mobile.loading( "hide" );
						},
						success: function (result) {
							if(result.status === 'success') {
								// set the auth cookie
								if (typeof result.token != 'undefined') setCookie('token',result.token,7);
								
								// go back to settings page, refresh
								$.mobile.pageContainer.pagecontainer("change", '/settings',{
									transition              : 'none',
									reloadPage              : true
								});
								
							} else {
								alert('Unable to process update. The server said: ' + result.data.message); 
							}
						},
						error: function (request,error) {
							// This callback function will trigger on unsuccessful action                
							alert('Network error has occurred; please try again.');
						}
					}); 

				} else {
					alert('Please enter your card code');
				}
			} else {
				alert('Please enter your card number');
			}
		} else {
			alert('Please enter your full name as it appears on your card');
		}
	
		return false;
	});
	
	
	/**
	 * Cancel Recurring.
	 * This event will run when the settings page's cancel recurring subscription button is clicked.
	 * Sends the purchase request to the server.
	 */
	$(document).on('click', '.safetext-settings .safetext-disable-autorenew-button', function(event) {	
		$.ajax({url: '/settings/cancelrecurring',
			headers: {'x-safetext-token': getCookie('token')},
			type: 'post',               
			async: 'true',
			dataType: 'json',
			beforeSend: function() {
				// This callback function will trigger before data is sent
				$.mobile.loading( 'show');
			},
			complete: function() {
				// This callback function will trigger on data sent/received complete
				$.mobile.loading( "hide" );
			},
			success: function (result) {
				if(result.status === 'success') {
					// set the auth cookie
					if (typeof result.token != 'undefined') setCookie('token',result.token,7);
					
					// refresh page
					$.mobile.pageContainer.pagecontainer("change", window.location.href,{
						allowSamePageTransition : true,
						transition              : 'none',
						showLoadMsg             : false,
						reloadPage              : true
					});
					
				} else {
					alert('Unable to process update. The server said: ' + result.data.message); 
				}
			},
			error: function (request,error) {
				// This callback function will trigger on unsuccessful action                
				alert('Network error has occurred; please try again.');
			}
		}); 
		
		return false;
	});
	
	
	
	
	
	
	
	/**
	 * Startup:
	 * The following will be run only for the initially loaded page.
	 * 
	 */
	$( document ).ready(function() {
		Safetext.startPage = $( document ).find("[data-role='page']");
		Safetext.lastPage = Safetext.startPage;
		
		Safetext.pageManager = new MsPageManager(); // single instance of this object, to be used by all pages		
		Safetext.pageManager.pageChange(Safetext.startPage); // run any pagechange tasks on the initial page	
	});
	
	
	
	
	
	
	
	
	
	

})();