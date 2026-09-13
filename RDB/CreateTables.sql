/*-- in your master database

CREATE LOGIN NandaSurendra

WITH PASSWORD = 'MI$T460Instructor';

-- switch to your mist460-rdb-lastname database;

CREATE USER NandaSurendra

FOR LOGIN NandaSurendra;

ALTER ROLE db_owner ADD MEMBER NandaSurendra;
*/
/* Run this script before InsertData.sql. */
drop table if exists RoomAvailability;
drop table if exists Reservation;
drop table if exists AppUser;
drop table if exists Room;
go

create table Room
(
    RoomID int identity(1,1) primary key,
    RoomNumber varchar(10) not null,
    Floor int not null,
    Seats int not null check (Seats > 0),
    Whiteboard bit not null,
    CurrentStatus varchar(20) not null
);
go

create table AppUser
(
    AppUserID int identity(1,1) primary key,
    FirstName varchar(50) not null,
    LastName varchar(50) not null,
    Email varchar(254) not null unique
);
go

create table Reservation
(
    ReservationID int identity(1,1) primary key,
    AppUserID int not null,
    ReservationDateTime datetime2 not null,
    CheckinDateTime datetime2 null,
    CheckoutDateTime datetime2 null,
    -- TotalTime is derived from actual check-in/out, in minutes.
    TotalTime as datediff(minute, CheckinDateTime, CheckoutDateTime),
    ReservationStatus varchar(20) not null,
    constraint FK_Reservation_AppUser foreign key (AppUserID) references AppUser(AppUserID),
    constraint CK_Reservation_Checkout check
        (CheckoutDateTime is null or
            (CheckinDateTime is not null and CheckoutDateTime >= CheckinDateTime))
);
go

create table RoomAvailability
(
    RoomAvailabilityID int identity(1,1) primary key,
    RoomID int not null,
    AvailableDate date not null,
    AvailableStartTime time not null,
    AvailableEndTime time not null,
    AvailabilityStatus varchar(20) not null,
    -- Each slot has at most one reservation; a reservation can include multiple slots.
    ReservationID int null,
    constraint FK_RoomAvailability_Room foreign key (RoomID) references Room(RoomID),
    constraint FK_RoomAvailability_Reservation foreign key (ReservationID) references Reservation(ReservationID),
    constraint CK_RoomAvailability_Time check (AvailableEndTime > AvailableStartTime)
);
go
