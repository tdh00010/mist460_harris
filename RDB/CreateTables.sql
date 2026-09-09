/*-- in your master database

CREATE LOGIN NandaSurendra

WITH PASSWORD = 'MI$T460Instructor';

-- switch to your mist460-rdb-lastname database;

CREATE USER NandaSurendra

FOR LOGIN NandaSurendra;

ALTER ROLE db_owner ADD MEMBER NandaSurendra;
*/
Drop table if exists Room;
drop table if exists RoomAvailability;

go

create table Room
(
    RoomID int identity(1,1) primary key,
    RoomName varchar(10) not null,
    Whiteboard bit not null,
 );

 go

 create table RoomAvailability
 (
    RoomAvailabilityID int identity(1,1) primary key,
    RoomID int not null,
    AvailableDate date not null,
    AvailableStartTime time not null,
    constraint FK_RoomAvailability_Room foreign key (RoomID) references Room(RoomID)
 );