select 
* from Room
where Whiteboard = 1;

select * from RoomAvailability;

go

-- Show available time slots with room details.
create or alter view AvailableRooms as
select r.RoomNumber, r.Floor, r.Seats, r.Whiteboard,
       ra.AvailableDate, ra.AvailableStartTime, ra.AvailableEndTime
from Room r
join RoomAvailability ra on r.RoomID = ra.RoomID
where ra.AvailabilityStatus = 'Available'
  and ra.ReservationID is null
  and r.CurrentStatus = 'Available';
go

-- Find available rooms for a particular date.
create or alter procedure FindAvailableRooms
    @AvailableDate date
as
begin
    set nocount on;

    select *
    from AvailableRooms
    where AvailableDate = @AvailableDate
    order by RoomNumber, AvailableStartTime;
end;
go

-- Examples:
-- select * from AvailableRooms;
-- exec FindAvailableRooms @AvailableDate = '2024-09-01';
