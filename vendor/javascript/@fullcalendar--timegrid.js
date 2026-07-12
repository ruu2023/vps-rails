// @fullcalendar/timegrid@6.1.21 downloaded from https://ga.jspm.io/npm:@fullcalendar/timegrid@6.1.21/index.js

import{createPlugin as e}from"@fullcalendar/core/index.js";import{DayTimeColsView as t}from"@fullcalendar/timegrid/internal.js";import"@fullcalendar/core/internal.js";import"@fullcalendar/core/preact.js";import"@fullcalendar/daygrid/internal.js";var n=e({name:`@fullcalendar/timegrid`,initialView:`timeGridWeek`,optionRefiners:{allDaySlot:Boolean},views:{timeGrid:{component:t,usesMinMaxTime:!0,allDaySlot:!0,slotDuration:`00:30:00`,slotEventOverlap:!0},timeGridDay:{type:`timeGrid`,duration:{days:1}},timeGridWeek:{type:`timeGrid`,duration:{weeks:1}}}});export{n as default};

