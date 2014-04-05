-- --------------------------------------------------------------------------------
-- Generate Token
-- Generates a device auth token for a user
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `generateToken` (IN usernameIn VARCHAR(24), IN passIn VARCHAR(24), IN deviceSig VARCHAR(64), IN deviceDesc VARCHAR(64))
BEGIN
	/* get user ID */
	SET @userId = (SELECT `id` FROM users WHERE `username` = usernameIn AND `pass` = passIn);
        SET @msg = NULL;
	
	IF @userId IS NOT NULL THEN
		/* see if this device exists */
		SET @deviceId = (SELECT `id` FROM sync_device WHERE `user_id` = @userId AND `signature` = deviceSig);
		IF @deviceId IS NOT NULL THEN
			/* get the existing token */
			SET @token = (SELECT `token` FROM sync_device WHERE `id` = @deviceId);

			/* if token is empty, meaning it has been previously expired or cleared, generate a new one */
			if @token < 1 THEN
				SET @token = CAST(MD5(CONCAT(CONCAT('SafeText-hashsalt', usernameIn), UNIX_TIMESTAMP())) AS CHAR);
				UPDATE sync_device SET `token`=@token, `token_expires`=DATE_ADD(CURDATE(),INTERVAL 5 DAY), `description`=deviceDesc WHERE `user_id` = @userId AND `id` = @deviceId; 
			ELSE
				/* re-auth: a device which already has a valid token assigned to it is re-authenticating.*/
				IF deviceSig != 'webclient' THEN
					/* reset the init flag */
					UPDATE sync_device SET `is_initialized`=0, `description`=deviceDesc WHERE `user_id` = @userId AND `id` = @deviceId;
					/* clear the sync queue */
					DELETE FROM sync_queue WHERE `user_id` = @userId AND `device_id` = @deviceId;
				END IF;
			END IF;
			
		ELSE
			/* make sure that there aren’t too many devices already registered */
			SET @numDevices = (SELECT COUNT(*) FROM `sync_device` WHERE user_id=@userId AND signature != 'webclient');

			IF @numDevices < 2 OR deviceSig = 'webclient' THEN
				/* create new device entry */
				SET @tokenString = CAST(MD5(CONCAT(CONCAT('SafeText-hashsalt', usernameIn), UNIX_TIMESTAMP())) AS CHAR);
				INSERT INTO sync_device (id,user_id,signature,description,is_initialized,token,token_expires) VALUES('', @userId, deviceSig, deviceDesc, '0', @tokenString, DATE_ADD(CURDATE(),INTERVAL 5 DAY));
				IF LAST_INSERT_ID() IS NOT NULL THEN
					SET @token = @tokenString;
				ELSE
					SET @userId = 0;
					SET @token = NULL;
					SET @msg = "Unable to create new token";
				END IF;
			ELSE
				SET @userId = 0;
				SET @msg = "Too many devices registered. Unregister unused devices using the web client Settings page";
			END IF;
		END IF;

	ELSE
		/* user/pass didn't match */
		SET @userId = 0;
        SET @token = NULL;
		SET @msg = "No match found for that username and password";
    END IF;

	SELECT @userId AS id, @token AS token, @msg AS msg;

END $$


-- --------------------------------------------------------------------------------
-- Expire Token
-- Clears a user's auth token.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `expireToken`(IN tokenIn VARCHAR(64))
BEGIN
	UPDATE sync_device SET `token`='', `token_expires`= CURDATE() WHERE `token` = tokenIn LIMIT 1; 
END


-- --------------------------------------------------------------------------------
-- Unregister Device
-- Completely removes a user's device from SafeText
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `unregisterDevice`(IN deviceIdIn INT UNSIGNED, IN tokenIn VARCHAR(64))
BEGIN
	/* If no device ID was passed, unregister using the token */
	IF deviceIdIn = '' THEN
		SET @deviceId = (SELECT `id` FROM sync_device WHERE `token` = tokenIn);
	ELSE
		SET @deviceId = deviceIdIn;
	END IF;

	IF @deviceId IS NOT NULL THEN
		/* clear sync queue */
		DELETE FROM sync_queue WHERE `device_id` = @deviceId;

		/* clear device */
		DELETE FROM sync_device WHERE `id` = @deviceId LIMIT 1;

	END IF;

END


-- --------------------------------------------------------------------------------
-- Token to User.
-- Given an auth token, load the associated user and dependency fields
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `tokenToUser` (IN tokenIn VARCHAR(64))
BEGIN
	/* declare the user variables */
	declare userid int unsigned;
	declare user_username varchar(16);
	declare user_firstname varchar(32);
	declare user_lastname varchar(32);
	declare user_email varchar(64);
	declare user_phone varchar(32);
	declare user_pass varchar(16);
	declare user_date_added datetime;
	declare user_date_last_pass_update datetime;
	declare user_language varchar(2);
	declare user_notifications_on tinyint(2) unsigned;
	declare user_whitelist_only tinyint(2) unsigned;
	declare user_enable_panic tinyint(2) unsigned;
	declare user_subscription_level tinyint unsigned;

	/* declare device variables */
	declare device_id int unsigned;
	declare device_user_id int unsigned;
	declare device_signature varchar(64);
	declare device_description varchar(32);
	declare device_is_initialized tinyint(2) unsigned;
	declare device_token varchar(64);
	declare device_token_expires datetime;


	/* look up device by passed auth token */
	select id,user_id,signature,description,is_initialized,token,token_expires
		INTO device_id,device_user_id,device_signature,device_description,device_is_initialized,device_token,device_token_expires
		FROM sync_device WHERE token=tokenIn;
	IF device_id > 0 THEN

		/* check to see if token is expired */
		SET @token = device_token;
		IF CURDATE() > device_token_expires then
			/* generate new token */
			SET @token = CAST(MD5(CONCAT(CONCAT('SafeText-hashsalt', device_signature), UNIX_TIMESTAMP())) AS CHAR);
			UPDATE sync_device SET `token`=@token,`token_expires`=DATE_ADD(CURDATE(),INTERVAL 5 DAY) WHERE id=device_id LIMIT 1;
		END IF;

		/* look up associated user*/
		select id,username,firstname,lastname,email,phone,pass,date_added,date_last_pass_update,`language`,notifications_on,whitelist_only,enable_panic,subscription_level
			INTO userid,user_username,user_firstname,user_lastname,user_email,user_phone,user_pass,user_date_added,user_date_last_pass_update,user_language,user_notifications_on,user_whitelist_only,user_enable_panic,user_subscription_level
			FROM users WHERE id=device_user_id;


		/* format response columns */
		select userid AS id,user_username AS username,user_firstname AS firstname,user_lastname as lastname, user_email AS email,user_phone AS phone,user_pass AS pass,user_date_added as date_added,user_date_last_pass_update AS last_pass_update,user_language AS `language`,user_notifications_on AS notifications_on,user_whitelist_only AS whitelist_only,user_enable_panic AS enable_panic,user_subscription_level as subscription_level,device_id AS `device.id`,device_signature AS `device.signature`,device_description AS `device.description`,device_is_initialized AS `device.is_initialized`,@token AS `device.token`;

	ELSE
		/* token not found */
		SELECT 0 as id;
	END IF;

END


-- --------------------------------------------------------------------------------
-- Sync Contact Delete.
-- Sync's a delete contact event to all devices of a particular user, including the web client.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `syncContactDelete` (IN userId int unsigned, IN contactUserId int unsigned)
BEGIN
	DECLARE deviceId int unsigned;
	DECLARE done INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT id FROM sync_device WHERE `user_id`=userId AND is_initialized=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	/* Delete the contact */
	DELETE FROM contacts WHERE `user_id`=userId AND `contact_user_id`=contactUserId LIMIT 1;

	/* Delete any sync records queued for this contact */
	DELETE FROM sync_queue WHERE `user_id`=userId AND `pk`=contactUserId AND tablename='contacts';

	/* Queue a delete record for every device */
	OPEN cur;
		read_loop: LOOP
			FETCH cur INTO deviceId;			
			IF done THEN
				LEAVE read_loop;
			END IF;
			
			INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'contacts',contactUserId,'{"is_deleted":"1"}',0);

		END LOOP;
	CLOSE cur;

END


-- --------------------------------------------------------------------------------
-- Sync Contact.
-- Sync's a contact add/update to all devices of a particular user, including the web client.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `syncContact` (IN userId int unsigned, IN contactUserId int unsigned, IN nameIn VARCHAR(64), IN emailIn VARCHAR(64), IN phoneIn VARCHAR(32), isWhitelistIn tinyint(1) unsigned, isBlockedIn tinyint(1) unsigned)
BEGIN
	DECLARE deviceId int unsigned;
	DECLARE done INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT id FROM sync_device WHERE `user_id`=userId AND is_initialized=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	/* Update/Create the contact */
	REPLACE INTO contacts (user_id,contact_user_id,name,email,phone,is_whitelist,is_blocked) VALUES (userId,contactUserId,nameIn,emailIn,phoneIn,isWhitelistIn,isBlockedIn);

	/* Delete any sync records queued for this contact */
	DELETE FROM sync_queue WHERE `user_id`=userId AND `pk`=contactUserId AND tablename='contacts';

	/* Queue a pull record for every device */
	SET nameIn = REPLACE(nameIn, '\\', '\\\\'); /* JSON encoding for \ */
	SET nameIn = REPLACE(nameIn, '"', '\\"'); /* JSON encoding for " */
	
	OPEN cur;
		read_loop: LOOP
			FETCH cur INTO deviceId;			
			IF done THEN
				LEAVE read_loop;
			END IF;
			
			INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'contacts',contactUserId,CONCAT_WS('','{"name":"',nameIn,'","email":"',emailIn,'","phone":"',phoneIn,'","is_whitelist":"',isWhitelistIn,'","is_blocked":"',isBlockedIn,'","is_updated":"0","is_deleted":"0"}'),0);

		END LOOP;
	CLOSE cur;

END


-- --------------------------------------------------------------------------------
-- Sync Message Delete.
-- Sync's a delete message event to all devices of a particular user, including the web client.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `syncMessageDelete` (IN messageId int unsigned)
BEGIN
	DECLARE deviceId, userId int unsigned;
	DECLARE done INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT sync_device.id, sync_device.user_id FROM sync_device, participants WHERE participants.message_id =messageId AND participants.contact_id = sync_device.user_id AND sync_device.is_initialized=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	/* Delete the message */
	DELETE FROM messages WHERE `id`=messageId LIMIT 1;

	/* Delete any sync records queued for this message */
	DELETE FROM sync_queue WHERE `pk`=messageId AND tablename='messages';

	/* Queue a delete record for every device of every participant */
	OPEN cur;
		read_loop: LOOP
			FETCH cur INTO deviceId, userId;			
			IF done THEN
				LEAVE read_loop;
			END IF;
			
			INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'messages',messageId,'{"is_deleted":"1"}',0);

		END LOOP;
	CLOSE cur;

	/* Delete the participants records */
	DELETE FROM participants WHERE `message_id`=messageId;

END


-- --------------------------------------------------------------------------------
-- Sync Message.
-- Sync's a message *update* to all devices of each participant of the message
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `syncMessage` (IN userIdIn int unsigned, IN messageId int unsigned, IN isImportantIn tinyint(1) unsigned, IN isDraftIn tinyint(1) unsigned, IN isReadIn tinyint(1) unsigned)
BEGIN
	DECLARE deviceId, userId, senderId, recipientId int unsigned;
	DECLARE isImportant, isDraft, isRead tinyint(1) unsigned;
	DECLARE readDate, sentDate, expireDate datetime;
	DECLARE msgContent text;
	DECLARE done INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT sync_device.id, sync_device.user_id FROM sync_device, participants WHERE participants.message_id =messageId AND participants.contact_id = sync_device.user_id AND sync_device.is_initialized=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	/* Get the message's current values */
	SELECT content,is_important,is_draft,is_read,read_date,sent_date,expire_date
		INTO msgContent,isImportant,isDraft,isRead,readDate,sentDate,expireDate
		FROM messages WHERE id=messageId;
	
	/* Get the sender ID */
	SET senderId = (SELECT `contact_id` FROM participants WHERE `message_id` = messageId AND `is_sender` = 1);

	/* Get the recipient ID */
	SET recipientId = (SELECT `contact_id` FROM participants WHERE `message_id` = messageId AND `is_sender` = 0);
	
	/* Determine what can be changed based on this user's role (sender/recipient) */
	IF userIdIn = senderId THEN
		SET isImportant = isImportantIn;
		SET isDraft = isDraftIn;
	ELSE
		SET isRead = isReadIn;
		IF isRead = 1 AND readDate = '0000-00-00 00:00:00' THEN
			SET readDate=NOW();
		END IF;
	END IF;

	/* Update the message */
	UPDATE messages set is_important=isImportant, is_draft=isDraft, is_read=isRead, read_date=readDate WHERE id=messageId LIMIT 1;

	/* Delete any sync records queued for this message */
	DELETE FROM sync_queue WHERE `pk`=messageId AND tablename='messages';

	/* Queue a pull record for every device */
	SET msgContent = REPLACE(msgContent, '\\', '\\\\'); /* JSON encoding for \ */
	SET msgContent = REPLACE(msgContent, '"', '\\"'); /* JSON encoding for " */

	OPEN cur;
		read_loop: LOOP
			FETCH cur INTO deviceId, userId;			
			IF done THEN
				LEAVE read_loop;
			END IF;
			
			IF isDraft = 0 OR userId = senderId THEN
				INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'messages',messageId,CONCAT_WS('','{"sender":"',senderId,',"recipients":["',recipientId,'"],","content":"',msgContent,'","is_read":"',isRead,'","is_important":"',isImportant,'","is_draft":"',isDraft,'","sent_date":"',sentDate,'","read_date":"',readDate,'","expire_date":"',expireDate,'","is_updated":"0","is_deleted":"0"}'),0);
			END IF;
			
		END LOOP;
	CLOSE cur;

END


-- --------------------------------------------------------------------------------
-- Sync Pull.
-- Returns sync records from the server for a particular device.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `syncPull`(IN userId int unsigned, IN deviceId int unsigned)
BEGIN

	/* Is this device initialized? */
	SET @is_init = (SELECT `is_initialized` FROM sync_device WHERE `user_id` = @userId AND `id` = deviceId);
	IF @is_init = 1 THEN
		/* Remove any previously pulled queue records */
		DELETE FROM sync_queue WHERE user_id=userId AND device_id=deviceId AND is_pulled=1;
	
		/* Flag unpulled records as pulled, since we're going to pull them now */
		UPDATE sync_queue SET is_pulled=1 WHERE user_id=userId AND device_id=deviceId;
	
		/* Pull the flagged records */
		SELECT tablename,pk,vals FROM sync_queue WHERE user_id=userId AND device_id=deviceId AND is_pulled=1 ORDER BY id;
	ELSE
		/* init device */
		UPDATE sync_device SET is_initialized=1 WHERE user_id=userId AND id=deviceId;
	END IF;
	
END


-- --------------------------------------------------------------------------------
-- Send Message.
-- Sends a new message from one user to another. Returns newly generated message ID.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `sendMessage` (IN senderIdIn int unsigned, IN recipientIdIn int unsigned, IN contentIn text, IN isImportantIn tinyint(1) unsigned, IN isDraftIn tinyint(1) unsigned, IN lifetimeIn tinyint unsigned)
BEGIN
	DECLARE deviceId, userId, messageId, existingContact int unsigned;
	DECLARE newcontactName, newcontactEmail, newContactPhone VARCHAR(64);
	DECLARE sentDate,expireDate datetime;
	DECLARE done, isAllowed INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT id, user_id FROM sync_device WHERE (user_id = senderIdIn OR user_id=recipientIdIn) AND is_initialized=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	/* make sure that this recipient allows messages from the sender */
	SET @whitelistFlag = (SELECT whitelist_only FROM users WHERE id=recipientIdIn);
	IF @whitelistFlag = 0 THEN
		SET isAllowed = TRUE;
    ELSE
		SET @whitelistedUser = (SELECT contact_user_id FROM contacts WHERE user_id=recipientIdIn AND contact_user_id=senderIdIn AND is_whitelist=1);
		IF @whitelistedUser = senderIdIn THEN
			SET isAllowed = TRUE;
		END IF;
	END IF;

	IF isAllowed THEN
		/* make sure sender is not blocked */
		SET @blockedUser = (SELECT contact_user_id FROM contacts WHERE user_id=recipientIdIn AND contact_user_id=senderIdIn AND is_blocked=1);
		IF @blockedUser IS NULL THEN

			/* if sender is not already a contact of the recipient, add the sender now as a new contact */
			IF isDraftIn != 1 THEN
				SET existingContact = (SELECT contact_user_id FROM contacts WHERE user_id=recipientIdIn AND contact_user_id=senderIdIn);
				IF existingContact IS NULL THEN
					/* add sender as a new contact */
					SELECT CONCAT_WS(' ', firstname,lastname),email,phone
					INTO newcontactName,newcontactEmail,newcontactPhone
					FROM users WHERE id=senderIdIn;

					INSERT INTO contacts (`user_id`,`contact_user_id`,`name`,`email`,`phone`) VALUES(recipientIdIn,senderIdIn,newcontactName, newcontactEmail, newcontactPhone);

				END IF;
			END IF;

			/* send new message */
			SET sentDate = NOW();
			SET expireDate = DATE_ADD(NOW(),INTERVAL lifetimeIn HOUR);
			INSERT INTO messages (`id`,`content`,`is_important`,`is_draft`,`sent_date`,`expire_date`) VALUES(NULL, contentIn,isImportantIn,isDraftIn,sentDate,expireDate);

			/* obtain the new message ID */
			SET messageId = LAST_INSERT_ID();
			IF messageId IS NOT NULL THEN 

				/* create sender participant record */
				INSERT INTO participants (`message_id`,`contact_id`,`is_sender`) VALUES(messageId,senderIdIn,1);

				/* create recipient participant record */
				INSERT INTO participants (`message_id`,`contact_id`,`is_sender`) VALUES(messageId,recipientIdIn,0);


				/* Queue a pull record for every device */
				SET contentIn = REPLACE(contentIn, '\\', '\\\\'); /* JSON encoding for \ */
				SET contentIn = REPLACE(contentIn, '"', '\\"'); /* JSON encoding for " */
				SET newcontactName = REPLACE(newcontactName, '\\', '\\\\'); /* JSON encoding for \ */
				SET newcontactName = REPLACE(newcontactName, '"', '\\"'); /* JSON encoding for " */
				SET newcontactEmail = REPLACE(newcontactEmail, '\\', '\\\\'); /* JSON encoding for \ */
				SET newcontactEmail = REPLACE(newcontactEmail, '"', '\\"'); /* JSON encoding for " */
				SET newcontactPhone = REPLACE(newcontactPhone, '\\', '\\\\'); /* JSON encoding for \ */
				SET newcontactPhone = REPLACE(newcontactPhone, '"', '\\"'); /* JSON encoding for " */

				OPEN cur;
					read_loop: LOOP
						FETCH cur INTO deviceId, userId;			
						IF done THEN
							LEAVE read_loop;
						END IF;
						
						IF isDraftIn = 0 OR userId = senderIdIn THEN
							INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'messages',messageId,CONCAT_WS('','{"sender":"',senderIdIn,'","recipients":["',recipientIdIn,'"],"content":"',contentIn,'","is_read":"0","is_important":"',isImportantIn,'","is_draft":"',isDraftIn,'","sent_date":"',sentDate,'","read_date":"0000-00-00 00:00:00","expire_date":"',expireDate,'","is_updated":"0","is_deleted":"0"}'),0);
						END IF;

						IF existingContact IS NULL AND userId=recipientIdIn THEN
							INSERT INTO sync_queue (id,user_id,device_id,date_added,tablename,pk,vals,is_pulled) VALUES (null,userId,deviceId,NOW(),'contacts',senderIdIn,CONCAT_WS('','{"name":"',newcontactName,'","email":"',newcontactEmail,'","phone":"',newcontactPhone,'","is_whitelist":"0","is_blocked":"0","is_updated":"0","is_deleted":"0"}'),0);
						END IF;

					END LOOP;
				CLOSE cur;


				/* send newly generated message ID */
				SELECT messageId AS `key`;

			ELSE
				SELECT NULL AS `key`, 'There was an error trying to send that message' AS `msg`;
			END IF;
		ELSE
			SELECT NULL AS `key`, 'That recipient is not accepting messages' AS `msg`; /* blocked sender */
		END IF;
	ELSE
		SELECT NULL AS `key`, 'That recipient only accepts messages from contacts they have whitelisted' AS `msg`;
	END IF;

END


-- --------------------------------------------------------------------------------
-- Get Settings
-- Returns a user's account settings
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `getSettings`(IN userIdIn int unsigned)
BEGIN
	SELECT * FROM users where id=userIdIn;

END


-- --------------------------------------------------------------------------------
-- Put settings
-- Save a user's account settings
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `putSettings` (IN userIdIn int unsigned, IN usernameIn VARCHAR(16), IN firstnameIn VARCHAR(32), IN lastnameIn VARCHAR(32), emailIn VARCHAR(64), phoneIn VARCHAR(32), passIn VARCHAR(16), languageIn VARCHAR(2), notificationsOnIn TINYINT(1) unsigned, whitelistOnlyIn TINYINT(1) unsigned, enablePanicIn TINYINT(1) unsigned)
BEGIN
	DECLARE curUsername, curPass VARCHAR(16);
	DECLARE curDateLastPassUpdate datetime;
	DECLARE existingUserId int unsigned;
	
	/* load current username & password */
	SELECT username,pass,date_last_pass_update
		INTO curUsername,curPass,curDateLastPassUpdate
		FROM users WHERE id=userIdIn;
	
	IF curUsername IS NOT NULL THEN
		/* by default, keep current username and password if none is provided */
		IF usernameIn = '' THEN
			SET usernameIn = curUsername;
		END IF;
		IF passIn = '' THEN
			SET passIn = curPass;
		END IF;

		/* If we're changing the password, update the pasword changed date */
		IF passIn != curPass THEN
			SET curDateLastPassUpdate = NOW();
		END IF;

		/* If we're changing username, make sure that it doesn't already exist for another user */
		IF usernameIn != curUsername THEN
			SET existingUserId = (SELECT id FROM users WHERE username=usernameIn AND id != userIdIn);
		END IF;
		IF existingUserId IS NULL THEN
			/* Save user settings */
			UPDATE users SET `username`=usernameIn,`firstname`=firstnameIn,`lastname`=lastnameIn,`email`=emailIn,`phone`=phoneIn,`pass`=passIn,`date_last_pass_update`=curDateLastPassUpdate,`language`=languageIn,`notifications_on`=notificationsOnIn,`whitelist_only`=whitelistOnlyIn,`enable_panic`=enablePanicIn WHERE id=userIdIn LIMIT 1;

			SELECT NULL AS `msg`;
		ELSE
			SELECT 'Username is already taken' AS `msg`;
		END IF;
	ELSE
		SELECT 'Cannot locate that user record in database' AS `msg`;
	END IF;

END


-- --------------------------------------------------------------------------------
-- Sync Last Pull.
-- Returns sync records that were previously sent to a particular device in its most recent sync
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `syncLastPull`(IN userId int unsigned, IN deviceId int unsigned)
BEGIN
	/* Pull the flagged records */
	SELECT tablename,pk,vals FROM sync_queue WHERE user_id=userId AND device_id=deviceId AND is_pulled=1 ORDER BY id;

END


-- --------------------------------------------------------------------------------
-- Contact Lookup
-- Returns users that match the full name passed. If users have enabled whitelist_only
-- and the searching user isn't whitelisted, they will not be returned.
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `contactLookup`(IN userIdIn int unsigned, IN queryStringIn VARCHAR(32))
BEGIN
	
	/* create temporary table to hold results */
	CREATE TEMPORARY TABLE IF NOT EXISTS results_table (id INT NOT NULL, firstname VARCHAR(32) NOT NULL, lastname VARCHAR(32) NOT NULL, email VARCHAR(64) NOT NULL, phone VARCHAR(64) NOT NULL, PRIMARY KEY (id)) AS (SELECT id,firstname,lastname,phone,email FROM users WHERE CONCAT_WS(' ',firstname,lastname) = queryStringIn AND whitelist_only = 0);

	/* add whitelist only users for whom this user is a whitelisted contact */
	INSERT INTO results_table SELECT users.id,users.firstname,users.lastname,users.phone,users.email FROM users,contacts WHERE CONCAT_WS(' ',users.firstname,users.lastname) = queryStringIn AND users.whitelist_only = 1 AND contacts.user_id=users.id AND contacts.contact_user_id = userIdIn AND contacts.is_blocked=0 AND contacts.is_whitelist=1;

	/* return stored hits */
	SELECT * FROM results_table;

	/* remove the temporary table */
	DROP TEMPORARY TABLE results_table;

END


-- --------------------------------------------------------------------------------
-- New User
-- Adds a new user to SafeText
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `newUser`(IN usernameIn VARCHAR(24), IN passIn VARCHAR(24), IN firstnameIn VARCHAR(32), IN lastnameIn VARCHAR(32), IN emailIn VARCHAR(64), IN deviceSig VARCHAR(64), IN deviceDesc VARCHAR(64))
BEGIN
	/* check username availability */
	SET @userId = (SELECT `id` FROM users WHERE `username` = usernameIn);
	SET @msg = NULL;
	
	IF @userId IS NULL THEN
		/* add the user */
		INSERT INTO users (`id`,`username`,`firstname`,`lastname`,`email`,`pass`,`date_added`,`date_last_pass_update`,`language`,`notifications_on`,`whitelist_only`,`enable_panic`) VALUES(NULL,usernameIn,firstnameIn,lastnameIn,emailIn,passIn,NOW(),NOW(),'en',1,0,1);

		/* obtain the new user ID */
		SET @userId = LAST_INSERT_ID();
		IF @userId > 0 THEN
			/* create new device entry */
			SET @tokenString = CAST(MD5(CONCAT(CONCAT('SafeText-hashsalt', usernameIn), UNIX_TIMESTAMP())) AS CHAR);
			INSERT INTO sync_device (id,user_id,signature,description,is_initialized,token,token_expires) VALUES('', @userId, deviceSig, deviceDesc, '0', @tokenString, DATE_ADD(CURDATE(),INTERVAL 5 DAY));
			IF LAST_INSERT_ID() IS NOT NULL THEN
				SET @token = @tokenString;
			ELSE
				SET @userId = 0;
				SET @token = NULL;
				SET @msg = "Unable to create new token";
			END IF;
		ELSE
			/* unable to add new user */
			SET @userId = 0;
			SET @token = NULL;
			SET @msg = "Unable to add your user details. Please contact us for assistance.";
		END IF;
	ELSE
		/* username already exists */
		SET @userId = 0;
        SET @token = NULL;
		SET @msg = "That username is already taken";
    END IF;

	SELECT @userId AS id, @token AS token, @msg AS msg;

END


-- --------------------------------------------------------------------------------
-- Delete User
-- Removes a user and all dependencies
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `deleteUser` (IN userIdIn int unsigned)
BEGIN
	/* Delete contacts */
	DELETE FROM contacts WHERE `user_id`=userIdIn;

	/* Delete devices */
	DELETE FROM sync_device WHERE `user_id`=userIdIn LIMIT 3;

	/* Delete any sync records queued for this contact */
	DELETE FROM sync_queue WHERE `user_id`=userIdIn;

	/* Delete user record */
	DELETE FROM users WHERE `id`=userIdIn LIMIT 1;

	SELECT 'success' AS `status`;

END



-- --------------------------------------------------------------------------------
-- Messages
-- Returns messages for a user
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`maxdistrodb`@`%.%.%.%` PROCEDURE `messages`(IN userIdIn INT UNSIGNED, IN filterIn VARCHAR(12), IN startIn INT UNSIGNED, IN limitIn INT UNSIGNED)
BEGIN

	/* Create temporary table to work with, populated with all messages this user is a participant of */
	IF filterIn = 'sent' THEN
		PREPARE STMT FROM " CREATE TEMPORARY TABLE IF NOT EXISTS messages_lookup
			(id INT UNSIGNED NOT NULL, content TEXT NOT NULL, is_read TINYINT(1) UNSIGNED NOT NULL, is_important TINYINT(1) UNSIGNED NOT NULL, is_draft TINYINT(1) UNSIGNED NOT NULL, sent_date DATETIME NOT NULL, read_date DATETIME NOT NULL, expire_date DATETIME NOT NULL, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL, PRIMARY KEY (id))
			AS (SELECT messages.id, messages.content, messages.is_read, messages.is_important, messages.is_draft, messages.sent_date, messages.read_date, messages.expire_date, 0 AS sender, 0 AS recipient FROM messages,participants WHERE participants.message_id = messages.id AND participants.contact_id = ? AND participants.is_sender=1 ORDER BY messages.id LIMIT ?,?); ";
	ELSEIF filterIn = 'received' THEN
		PREPARE STMT FROM " CREATE TEMPORARY TABLE IF NOT EXISTS messages_lookup
			(id INT UNSIGNED NOT NULL, content TEXT NOT NULL, is_read TINYINT(1) UNSIGNED NOT NULL, is_important TINYINT(1) UNSIGNED NOT NULL, is_draft TINYINT(1) UNSIGNED NOT NULL, sent_date DATETIME NOT NULL, read_date DATETIME NOT NULL, expire_date DATETIME NOT NULL, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL, PRIMARY KEY (id))
			AS (SELECT messages.id, messages.content, messages.is_read, messages.is_important, messages.is_draft, messages.sent_date, messages.read_date, messages.expire_date, 0 AS sender, 0 AS recipient  FROM messages,participants WHERE participants.message_id = messages.id AND participants.contact_id = ? AND participants.is_sender=0 ORDER BY messages.id LIMIT ?,?); ";
	ELSEIF filterIn = 'draft' THEN
		PREPARE STMT FROM " CREATE TEMPORARY TABLE IF NOT EXISTS messages_lookup
			(id INT UNSIGNED NOT NULL, content TEXT NOT NULL, is_read TINYINT(1) UNSIGNED NOT NULL, is_important TINYINT(1) UNSIGNED NOT NULL, is_draft TINYINT(1) UNSIGNED NOT NULL, sent_date DATETIME NOT NULL, read_date DATETIME NOT NULL, expire_date DATETIME NOT NULL, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL, PRIMARY KEY (id))
			AS (SELECT messages.id, messages.content, messages.is_read, messages.is_important, messages.is_draft, messages.sent_date, messages.read_date, messages.expire_date, 0 AS sender, 0 AS recipient  FROM messages,participants WHERE participants.message_id = messages.id AND participants.contact_id = ? AND participants.is_sender=1 AND messages.is_draft=1 ORDER BY messages.id LIMIT ?,?); ";
	ELSEIF filterIn = 'important' THEN
		PREPARE STMT FROM " CREATE TEMPORARY TABLE IF NOT EXISTS messages_lookup
			(id INT UNSIGNED NOT NULL, content TEXT NOT NULL, is_read TINYINT(1) UNSIGNED NOT NULL, is_important TINYINT(1) UNSIGNED NOT NULL, is_draft TINYINT(1) UNSIGNED NOT NULL, sent_date DATETIME NOT NULL, read_date DATETIME NOT NULL, expire_date DATETIME NOT NULL, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL, PRIMARY KEY (id))
			AS (SELECT messages.id, messages.content, messages.is_read, messages.is_important, messages.is_draft, messages.sent_date, messages.read_date, messages.expire_date, 0 AS sender, 0 AS recipient  FROM messages,participants WHERE participants.message_id = messages.id AND participants.contact_id = ? AND participants.is_sender=0 AND messages.is_important=1 ORDER BY messages.id LIMIT ?,?); ";
	ELSE
		PREPARE STMT FROM " CREATE TEMPORARY TABLE IF NOT EXISTS messages_lookup
			(id INT UNSIGNED NOT NULL, content TEXT NOT NULL, is_read TINYINT(1) UNSIGNED NOT NULL, is_important TINYINT(1) UNSIGNED NOT NULL, is_draft TINYINT(1) UNSIGNED NOT NULL, sent_date DATETIME NOT NULL, read_date DATETIME NOT NULL, expire_date DATETIME NOT NULL, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL, PRIMARY KEY (id))
			AS (SELECT messages.id, messages.content, messages.is_read, messages.is_important, messages.is_draft, messages.sent_date, messages.read_date, messages.expire_date, 0 AS sender, 0 AS recipient  FROM messages,participants WHERE participants.message_id = messages.id AND participants.contact_id = ? ORDER BY messages.id LIMIT ?,?); ";
	END IF;

	SET @userId = userIdIn;
	SET @start = startIn;
	SET @limit = limitIn;
	EXECUTE STMT USING @userId, @start, @limit;
	DEALLOCATE PREPARE STMT;

	/* Add sender */
	UPDATE messages_lookup set sender=(SELECT contact_id FROM participants WHERE message_id=messages_lookup.id and is_sender=1);
	
	/* Add recipient. Only one recipient currently supported */
	UPDATE messages_lookup set recipient=(SELECT contact_id FROM participants WHERE message_id=messages_lookup.id and is_sender=0);

	/* return all table fields */
	SELECT * FROM messages_lookup;

	/* delete temporary table */
	DROP TEMPORARY TABLE messages_lookup;


END


-- --------------------------------------------------------------------------------
-- Contacts
-- Returns contacts for a user
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE `contacts` (IN userIdIn INT UNSIGNED, IN orderIn VARCHAR(24), IN startIn INT UNSIGNED, limitIn INT UNSIGNED)
BEGIN

	PREPARE STMT FROM " SELECT * FROM contacts WHERE user_id=? ORDER BY ? LIMIT ?,? ";

	SET @userId = userIdIn;
	SET @orderBy = orderIn;
	SET @start = startIn;
	SET @limit = limitIn;
	EXECUTE STMT USING @userId, @orderBy, @start, @limit;
	DEALLOCATE PREPARE STMT;

END