insert into Room (RoomNumber, Whiteboard) values
('301', 1),
('302', 0),
('401', 1),
('402', 0),
('501', 1);

go

insert into RoomAvailability (RoomID, AvailableDate, AvailableStartTime) values
(1, '2024-09-01', '08:00:00'),
(1, '2024-09-01', '10:00:00'),
(2, '2024-09-01', '09:00:00'),
(3, '2024-09-02', '11:00:00'),
(4, '2024-09-02', '13:00:00'),
(5, '2024-09-03', '14:00:00'),
(6, '2024-09-03', '15:00:00');

go