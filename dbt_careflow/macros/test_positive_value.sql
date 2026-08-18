{% test positive_value(model, column_name) %}
-- Returns rows where the column value is not positive (i.e., <= 0 or null)
select
    {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} <= 0
{% endtest %}
