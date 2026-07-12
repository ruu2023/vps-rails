// @fullcalendar/daygrid@6.1.21 downloaded from https://ga.jspm.io/npm:@fullcalendar/daygrid@6.1.21/index.js

import{createPlugin as e}from"@fullcalendar/core/index.js";import{TableDateProfileGenerator as t,DayGridView as n}from"@fullcalendar/daygrid/internal.js";import"@fullcalendar/core/internal.js";import"@fullcalendar/core/preact.js";var r=e({name:`@fullcalendar/daygrid`,initialView:`dayGridMonth`,views:{dayGrid:{component:n,dateProfileGeneratorClass:t},dayGridDay:{type:`dayGrid`,duration:{days:1}},dayGridWeek:{type:`dayGrid`,duration:{weeks:1}},dayGridMonth:{type:`dayGrid`,duration:{months:1},fixedWeekCount:!0},dayGridYear:{type:`dayGrid`,duration:{years:1}}}});export{r as default};

