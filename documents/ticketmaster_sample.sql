--contains info about user that Ticketmaster stores--
DROP TABLE IF EXISTS project.user_info CASCADE;
CREATE TABLE project.user_info (
	user_id varchar(15) NOT NULL,
	year_joined smallint NOT NULL,
	first_name varchar(20) NOT NULL,
	last_name varchar(20) NOT NULL,
	email varchar(30) UNIQUE NOT NULL,
	mobile char(10) UNIQUE NOT NULL,
	zip char(5) NOT NULL,
	CONSTRAINT pk_user_info PRIMARY KEY(user_id),
	CONSTRAINT ck_user_year CHECK(year_joined >= 1976 AND
	year_joined <= EXTRACT(YEAR FROM CURRENT_TIMESTAMP)::smallint)
);

-- keep track of performers/performances and what type of event 
DROP TABLE IF EXISTS project.artists CASCADE;
CREATE TABLE project.artists(
	performers varchar(30) NOT NULL, 
	event_type varchar(30) NOT NULL, 
	CONSTRAINT pk_artists PRIMARY KEY(performers)
);

-- table to keep track of venue info -- 
DROP TABLE IF EXISTS project.venue CASCADE;
CREATE TABLE project.venue(
	venue_name varchar(30),
	venue_type varchar(30),
	capacity int, 
	city varchar(20),
	state char(2),
	CONSTRAINT pk_venue PRIMARY KEY(venue_name)
);


-- details about the event -- 
DROP TABLE IF EXISTS project.event CASCADE;
CREATE TABLE project.event(
	event_id char(7) NOT NULL, 
	period tstzrange NOT NULL,
	venue varchar(30) NOT NULL, 
	ticket_limit smallint NOT NULL,
	performers varchar(30) NOT NULL, 
	CONSTRAINT pk_event PRIMARY KEY(event_id),
	CONSTRAINT ex_event_conflict EXCLUDE USING GIST(venue WITH =, period WITH &&)
);



--contains info about all existing tickets in database--
--add foreign key so that event_id matches future event table--
DROP TABLE IF EXISTS project.tickets CASCADE;
CREATE TABLE project.tickets(
	ticket_id char(7) NOT NULL,
	event_id char(7) NOT NULL,
	status varchar(9) NOT NULL, 
	seat_number char(4) NOT NULL,
	user_purchase varchar(15) NULL, 
	CONSTRAINT pk_tickets PRIMARY KEY(ticket_id),
	CONSTRAINT ck_tickets_status CHECK(status IN ('available','sold','in cart','refunded')),
	CONSTRAINT ck_tickets_user CHECK((user_purchase IS NULL and status = 'available')
	OR (user_purchase IS NOT NULL AND (status = 'sold' OR status = 'in cart' OR status = 'refunded')))
);


-- details about orders--
--note: if a ticket is added to booked, tickets become sold in tickets table--
DROP TABLE IF EXISTS project.orders CASCADE;
CREATE TABLE project.orders(
	order_id int GENERATED ALWAYS AS IDENTITY (START WITH 1000000 INCREMENT BY 1),
	user_id varchar(15) NOT NULL, 
	event_id char(7) NOT NULL,
	num_tickets smallint NOT NULL, 
	total_price numeric(6,2) NOT NULL,
	CONSTRAINT pk_orders PRIMARY KEY(order_id)
);


DROP TABLE IF EXISTS project.seat_chart CASCADE;
CREATE TABLE project.seat_chart(
	event_id char(7) NOT NULL,
	price numeric(6,2) NOT NULL,
	seat_number char(4) NOT NULL, 
	CONSTRAINT pk_seat_chart PRIMARY KEY(event_id, seat_number)
)
;
-- start of RELATION MAKING -- 

-- make sure user exists in user database with orders -- 
-- Cascade to update user info, set null as to not delete record of order if account is deleted --
ALTER TABLE project.orders
	ADD CONSTRAINT fk_orders_user FOREIGN KEY (user_id)
	REFERENCES project.user_info(user_id)
	ON UPDATE CASCADE
	ON DELETE SET NULL
;

-- make sure event exists for tickets --
-- if update event info cascade, if event does not exist then the ticket does not exist -- 
ALTER TABLE project.tickets
	ADD CONSTRAINT fk_tickets_events FOREIGN KEY (event_id)
	REFERENCES project.event(event_id)
	ON UPDATE CASCADE
	ON DELETE CASCADE
;

-- make sure artists still exist for events --
-- if update cascade, if delete anxd artist doesn't exist anymore, then no event -- 
ALTER TABLE project.event
	ADD CONSTRAINT fk_event_performers FOREIGN KEY(performers)
	REFERENCES project.artists(performers)
	ON UPDATE CASCADE
	ON DELETE CASCADE
;

-- make sure venue still exist for events --
-- if update cascade, if delete and venue doesn't exist anymore, then no event -- 
ALTER TABLE project.event
	ADD CONSTRAINT fk_event_venue FOREIGN KEY(venue)
	REFERENCES project.venue(venue_name)
	ON UPDATE CASCADE
	ON DELETE CASCADE
;
-- ensure seats in tickets exist in the seating charts for sepcific events -- 
-- using cascade to ensure that if seats become unavailable the ticket is unavailable -- 
ALTER TABLE project.tickets 
	ADD CONSTRAINT fk_ticket_seating FOREIGN KEY(event_id, seat_number)
	REFERENCES project.seat_chart(event_id, seat_number)
	ON UPDATE CASCADE
	ON DELETE CASCADE
;
	
-- make sure tickets purchased by user are less than limit! --
-- https://www.geeksforgeeks.org/postgresql/postgresql-trigger/ --
-- have to sum all tickets for users in orders table since different orders -- 
-- must create trigger function then connect to table for PostGreSQL -- 

CREATE OR REPLACE FUNCTION trg_ticketlimit()
RETURNS TRIGGER AS $$
BEGIN
	-- take sum of tickets in orders where user_id and event_id are the same--
	IF (SELECT SUM(num_tickets)
		FROM project.orders
		WHERE user_id = NEW.user_id
			AND event_id = NEW.event_id) 
		-- make sure sum is less than the event max --
		> (SELECT ticket_limit 
		FROM project.event 
		WHERE event_id = NEW.event_id)
	THEN 
		RAISE EXCEPTION 'Ticket Limit Exceeded!';
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_limit 
BEFORE INSERT OR UPDATE ON project.orders
FOR EACH ROW
EXECUTE FUNCTION trg_ticketlimit()
;

-- Refund tickets if event is canceled(event will be canceled if artist or venue are removed) -- 
CREATE OR REPLACE FUNCTION trg_refund_tickets() 
RETURNS TRIGGER AS $$
BEGIN 
	UPDATE project.tickets
	SET status = 'refunded'
	WHERE event_id = OLD.event_id;
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_refund_tickets 
AFTER DELETE ON project.event 
FOR EACH ROW
EXECUTE FUNCTION trg_refund_tickets() 
;

-- Ticket becomes available if the user purchasing deletes account 
CREATE OR REPLACE FUNCTION trg_avail_tickets() 
RETURNS TRIGGER AS $$
BEGIN 
	UPDATE project.tickets
	SET status = 'available',
		user_purchase = NULL
	WHERE user_purchase = OLD.user_id;
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_avail_tickets 
AFTER DELETE ON project.user_info 
FOR EACH ROW
EXECUTE FUNCTION trg_avail_tickets()
;
			