-- Run CreateTables.sql first. These IDs assume freshly created tables.
insert into Room (RoomNumber, Floor, Seats, Whiteboard, CurrentStatus) values
('301', 3, 4, 1, 'Available'),
('302', 3, 6, 0, 'Available'),
('401', 4, 8, 1, 'Available'),
('402', 4, 4, 0, 'Available'),
('501', 5, 10, 1, 'Available');
go

insert into AppUser (FirstName, LastName, Email) values
('Alex', 'Morgan', 'alex.morgan@example.com'),
('Jordan', 'Lee', 'jordan.lee@example.com'),
('Taylor', 'Brown', 'taylor.brown@example.com'),
('Casey', 'Wilson', 'casey.wilson@example.com'),
('Riley', 'Davis', 'riley.davis@example.com');
go

insert into Reservation
    (AppUserID, ReservationDateTime, CheckinDateTime, CheckoutDateTime, ReservationStatus) values
(1, '2024-08-30T12:00:00', '2024-09-01T08:00:00', '2024-09-01T09:00:00', 'Completed'),
(2, '2024-08-30T13:00:00', '2024-09-01T09:00:00', '2024-09-01T10:00:00', 'Completed'),
(3, '2024-08-31T10:00:00', '2024-09-02T11:00:00', '2024-09-02T12:00:00', 'Completed'),
(4, '2024-08-31T11:00:00', '2024-09-02T13:00:00', '2024-09-02T14:00:00', 'Completed'),
(5, '2024-09-01T12:00:00', '2024-09-03T14:00:00', '2024-09-03T16:00:00', 'Completed');
go

insert into RoomAvailability
    (RoomID, AvailableDate, AvailableStartTime, AvailableEndTime, AvailabilityStatus, ReservationID) values
(1, '2024-09-01', '08:00:00', '09:00:00', 'Reserved', 1),
(1, '2024-09-01', '10:00:00', '11:00:00', 'Available', null),
(2, '2024-09-01', '09:00:00', '10:00:00', 'Reserved', 2),
(3, '2024-09-02', '11:00:00', '12:00:00', 'Reserved', 3),
(4, '2024-09-02', '13:00:00', '14:00:00', 'Reserved', 4),
(5, '2024-09-03', '14:00:00', '15:00:00', 'Reserved', 5),
(5, '2024-09-03', '15:00:00', '16:00:00', 'Reserved', 5);
go
