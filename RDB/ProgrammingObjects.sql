-- Run after CreateTables.sql and InsertData.sql.

-- 1. Available rooms and their open time ranges.
create or alter view dbo.AvailableRooms as
select r.RoomID, r.RoomNumber, r.Floor, r.Seats, r.Whiteboard,
       a.AvailableDate, a.AvailableStartTime, a.AvailableEndTime
from dbo.Room r
join dbo.RoomAvailability a on r.RoomID = a.RoomID
where r.CurrentStatus = 'Available'
  and a.AvailabilityStatus = 'Available'
  and a.ReservationID is null;
go

-- 2. Room capacity and specifications. Use NULL to list all rooms.
create or alter function dbo.RoomSpecifications(@RoomID int)
returns table
as return
(
    select RoomID, RoomNumber, Floor, Seats, Whiteboard, CurrentStatus
    from dbo.Room
    where @RoomID is null or RoomID = @RoomID
);
go

-- 3. Available portions of a requested time range.
-- NULL RoomID or Floor means include all rooms or floors.
create or alter function dbo.AvailableRoomSlots
(@Date date, @Start time, @End time, @RoomID int, @Floor int)
returns table
as return
(
    select RoomID, RoomNumber, Floor, Seats, Whiteboard, AvailableDate,
           case when AvailableStartTime < @Start then @Start
                else AvailableStartTime end as SlotStart,
           case when AvailableEndTime > @End then @End
                else AvailableEndTime end as SlotEnd
    from dbo.AvailableRooms
    where AvailableDate = @Date
      and AvailableStartTime < @End and AvailableEndTime > @Start
      and @Start < @End
      and (@RoomID is null or RoomID = @RoomID)
      and (@Floor is null or Floor = @Floor)
);
go

-- 4. Student search by date, time, room, or floor.
create or alter procedure dbo.FindAvailableRooms
    @AvailableDate date,
    @StartTime time = '00:00',
    @EndTime time = '23:59:59.9999999',
    @RoomID int = null,
    @Floor int = null
as
begin
    set nocount on;
    if @AvailableDate is null or @StartTime is null or @EndTime is null
       or @StartTime >= @EndTime
        throw 50001, 'Enter a date and a start time before the end time.', 1;

    select *
    from dbo.AvailableRoomSlots(@AvailableDate, @StartTime, @EndTime, @RoomID, @Floor)
    order by RoomNumber, SlotStart;
end;
go

-- 5. Validate availability changes, including reservations across multiple rows.
create or alter trigger dbo.ValidateRoomAvailability
on dbo.RoomAvailability
after insert, update, delete
as
begin
    set nocount on;

    -- Lock affected rooms and reservations while checking their intervals.
    declare @ID int;
    select @ID = RoomID from dbo.Room with (updlock, holdlock)
    where RoomID in (select RoomID from inserted union select RoomID from deleted);
    select @ID = ReservationID from dbo.Reservation with (updlock, holdlock)
    where ReservationID in
        (select ReservationID from inserted union select ReservationID from deleted);

    if exists (
        select 1 from inserted
        where datepart(minute, AvailableStartTime) % 15 <> 0
           or datepart(minute, AvailableEndTime) % 15 <> 0
           or datepart(second, AvailableStartTime) <> 0
           or datepart(second, AvailableEndTime) <> 0
           or datepart(nanosecond, AvailableStartTime) <> 0
           or datepart(nanosecond, AvailableEndTime) <> 0
    )
        throw 50002, 'Start and end times must fall on exact 15-minute boundaries.', 1;

    if exists (
        select 1 from inserted
        where AvailabilityStatus not in ('Available', 'Reserved', 'Unavailable')
           or (ReservationID is not null and AvailabilityStatus <> 'Reserved')
           or (ReservationID is null and AvailabilityStatus = 'Reserved')
    )
        throw 50003, 'Reserved intervals must have a reservation; other intervals must not.', 1;

    if exists (
        select 1 from inserted i
        join dbo.RoomAvailability a with (updlock, holdlock)
          on a.RoomID = i.RoomID and a.AvailableDate = i.AvailableDate
         and a.RoomAvailabilityID <> i.RoomAvailabilityID
         and a.AvailableStartTime < i.AvailableEndTime
         and a.AvailableEndTime > i.AvailableStartTime
    )
        throw 50004, 'Time ranges for the same room cannot overlap.', 1;

    if exists (
        select a.ReservationID
        from dbo.RoomAvailability a with (updlock, holdlock)
        where a.ReservationID in
            (select ReservationID from inserted union select ReservationID from deleted)
        group by a.ReservationID
        having sum(datediff(minute, a.AvailableStartTime, a.AvailableEndTime)) > 120
            or count(distinct a.RoomID) > 1
            or count(distinct a.AvailableDate) > 1
            or sum(datediff(minute, a.AvailableStartTime, a.AvailableEndTime)) <>
               datediff(minute, min(a.AvailableStartTime), max(a.AvailableEndTime))
    )
        throw 50005, 'A reservation must be continuous, in one room on one date, and at most two hours.', 1;
end;
go


-- 6. A student can reserve repeatedly, but cannot hold overlapping bookings.
create or alter trigger dbo.PreventStudentOverlap
on dbo.RoomAvailability
after insert, update
as
begin
    set nocount on;
    declare @UserID int;
    select @UserID = u.AppUserID
    from dbo.AppUser u with (updlock, holdlock)
    join dbo.Reservation r on r.AppUserID = u.AppUserID
    where r.ReservationID in (select ReservationID from inserted);

    if exists (
        select 1
        from inserted i
        join dbo.Reservation r on r.ReservationID = i.ReservationID
        join dbo.Reservation other on other.AppUserID = r.AppUserID
        join dbo.RoomAvailability a with (updlock, holdlock)
          on a.ReservationID = other.ReservationID
        where other.ReservationID <> r.ReservationID
          and a.AvailableDate = i.AvailableDate
          and a.AvailableStartTime < i.AvailableEndTime
          and a.AvailableEndTime > i.AvailableStartTime
    )
        throw 50006, 'You already have a reservation during this time.', 1;
end;
go

-- Keep the owner fixed so changing a reservation cannot bypass overlap checks.
create or alter trigger dbo.KeepReservationOwner
on dbo.Reservation after update
as
begin
    set nocount on;
    if exists (select 1 from inserted i join deleted d on i.ReservationID = d.ReservationID
               where i.AppUserID <> d.AppUserID)
        throw 50007, 'A reservation cannot be transferred to another student.', 1;
end;
go

-- 8. Rooms with an open interval containing the current server-local time.
create or alter procedure dbo.FindRoomsAvailableNow
    @Floor int = null, @MinimumSeats int = 1, @Whiteboard bit = null
as
begin
    set nocount on;
    declare @Now datetime2 = sysdatetime();
    select * from dbo.AvailableRooms
    where AvailableDate = cast(@Now as date)
      and AvailableStartTime <= cast(@Now as time)
      and AvailableEndTime > cast(@Now as time)
      and (@Floor is null or Floor = @Floor)
      and Seats >= @MinimumSeats
      and (@Whiteboard is null or Whiteboard = @Whiteboard)
    order by RoomNumber;
end;
go

-- 9, 11. Book the selected time and immediately mark it Reserved.
-- Preserve the available portions before and after the booking.
create or alter procedure dbo.ReserveRoom
    @AppUserID int, @RoomID int, @AvailableDate date,
    @StartTime time, @EndTime time
as
begin
    set nocount on;
    set xact_abort on;
    if @AvailableDate is null or @StartTime is null or @EndTime is null
       or @StartTime >= @EndTime or datediff(minute, @StartTime, @EndTime) > 120
       or datepart(minute, @StartTime) % 15 <> 0 or datepart(minute, @EndTime) % 15 <> 0
       or datepart(second, @StartTime) <> 0 or datepart(second, @EndTime) <> 0
       or datepart(nanosecond, @StartTime) <> 0 or datepart(nanosecond, @EndTime) <> 0
        throw 50008, 'Choose 15 to 120 minutes on exact quarter-hour boundaries.', 1;

    begin try
        begin transaction;
        if not exists (select 1 from dbo.AppUser with (updlock, holdlock) where AppUserID = @AppUserID)
            throw 50009, 'Student does not exist.', 1;
        if not exists (select 1 from dbo.Room with (updlock, holdlock)
                       where RoomID = @RoomID and CurrentStatus = 'Available')
            throw 50010, 'Room does not exist or is unavailable.', 1;

        select * into #Selected
        from dbo.RoomAvailability with (updlock, holdlock)
        where RoomID = @RoomID and AvailableDate = @AvailableDate
          and AvailableStartTime < @EndTime and AvailableEndTime > @StartTime;

        if exists (select 1 from #Selected where ReservationID is not null or AvailabilityStatus <> 'Available')
           or (select coalesce(sum(datediff(minute,
               case when AvailableStartTime < @StartTime then @StartTime else AvailableStartTime end,
               case when AvailableEndTime > @EndTime then @EndTime else AvailableEndTime end)), 0)
               from #Selected) <> datediff(minute, @StartTime, @EndTime)
            throw 50011, 'The entire requested time must be available. Search again.', 1;

        insert dbo.Reservation(AppUserID, ReservationDateTime, ReservationStatus)
        values (@AppUserID, sysdatetime(), 'Confirmed');
        declare @ReservationID int = convert(int, scope_identity());

        delete dbo.RoomAvailability
        where RoomAvailabilityID in (select RoomAvailabilityID from #Selected);

        insert dbo.RoomAvailability
            (RoomID, AvailableDate, AvailableStartTime, AvailableEndTime, AvailabilityStatus, ReservationID)
        select @RoomID, @AvailableDate, AvailableStartTime, @StartTime, 'Available', null
        from #Selected where AvailableStartTime < @StartTime
        union all
        select @RoomID, @AvailableDate, @EndTime, AvailableEndTime, 'Available', null
        from #Selected where AvailableEndTime > @EndTime
        union all
        select @RoomID, @AvailableDate, @StartTime, @EndTime, 'Reserved', @ReservationID;

        commit;
        select @ReservationID as ReservationID;
    end try
    begin catch
        if @@trancount > 0 rollback;
        throw;
    end catch;
end;
go

-- 7. Only the owner can check in, during their reserved time.
create or alter procedure dbo.CheckIn
    @AppUserID int, @ReservationID int
as
begin
    set nocount on;
    declare @Now datetime2 = sysdatetime();
    update dbo.Reservation
    set CheckinDateTime = @Now, ReservationStatus = 'CheckedIn'
    where ReservationID = @ReservationID and AppUserID = @AppUserID
      and ReservationStatus = 'Confirmed' and CheckinDateTime is null
      and exists (
          select 1 from dbo.RoomAvailability a
          where a.ReservationID = @ReservationID
            and a.AvailableDate = cast(@Now as date)
            and a.AvailableStartTime <= cast(@Now as time)
            and a.AvailableEndTime > cast(@Now as time)
      );
    if @@rowcount = 0
        throw 50012, 'Check-in requires your confirmed reservation during its scheduled time.', 1;
end;
go

-- 7. Record checkout; TotalTime is already computed by the table.
-- The scheduled interval stays reserved until its original end time.
create or alter procedure dbo.CheckOut
    @AppUserID int, @ReservationID int
as
begin
    set nocount on;
    update dbo.Reservation
    set CheckoutDateTime = sysdatetime(), ReservationStatus = 'Completed'
    where ReservationID = @ReservationID and AppUserID = @AppUserID
      and ReservationStatus = 'CheckedIn' and CheckoutDateTime is null;
    if @@rowcount = 0
        throw 50013, 'Check-out requires your checked-in reservation.', 1;
end;
go

-- 10, 11. Cancel an unused booking and release its availability atomically.
create or alter procedure dbo.CancelReservation
    @AppUserID int, @ReservationID int
as
begin
    set nocount on;
    set xact_abort on;
    begin try
        begin transaction;
        declare @UserID int;
        select @UserID = AppUserID from dbo.AppUser with (updlock, holdlock)
        where AppUserID = @AppUserID;

        update dbo.Reservation
        set ReservationStatus = 'Cancelled'
        where ReservationID = @ReservationID and AppUserID = @AppUserID
          and ReservationStatus = 'Confirmed' and CheckinDateTime is null;
        if @@rowcount = 0
            throw 50014, 'Only your unused confirmed reservation can be cancelled.', 1;

        update dbo.RoomAvailability
        set ReservationID = null, AvailabilityStatus = 'Available'
        where ReservationID = @ReservationID;
        commit;
    end try
    begin catch
        if @@trancount > 0 rollback;
        throw;
    end catch;
end;
go

-- Workflow examples (use dates with published availability and real IDs):
-- exec dbo.FindRoomsAvailableNow @Floor = 4, @MinimumSeats = 4;
-- exec dbo.FindAvailableRooms '20260828', '10:00', '14:00', @Floor = 4;
-- exec dbo.ReserveRoom 1, 3, '20260828', '10:00', '12:00';
-- Use the ReservationID returned by ReserveRoom below:
-- exec dbo.CheckIn 1, 6;
-- exec dbo.CheckOut 1, 6;
-- Or cancel before checking in:
-- exec dbo.CancelReservation 1, 6;
