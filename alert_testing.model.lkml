connection: "thelook_events_redshift"

include: "basic_users.view"
include: "order_items.view"
explore: alert_testing {
  from: basic_users
  view_name: users
  join: order_items {
    sql_on: ${users.id}=${order_items.user_id} ;;
    relationship: one_to_many
    type: left_outer
  }
}

view: trigger_ndt {
  derived_table: {
    explore_source: alert_testing {
      column: order_id {field:order_items.order_id}
      column: created_raw {field:order_items.created_raw}
      sort: {field:order_items.created_date desc:yes}
      filters: {field:order_items.created_date value:"before 10 days ago"}
    }
  }
  dimension: order_id {}
  dimension: created_raw {}
}
explore: trigger_ndt {}

# datagroup: alert_trigger_test1__outlier_on_count_by_age{
#   sql_trigger:
# with data as
# (
# SELECT
#   basic_users.age AS age,
#   COUNT(*) AS user_count,
#   row_number() over(ORDER BY COUNT(*) DESC) as row
# FROM public.users  AS basic_users
#
# -- where age>20
#
# GROUP BY 1
# ORDER BY 2 DESC
# LIMIT 2
# )
# select
# -- max(user_count)-min(user_count) as top_value_difference_from_second,
# case when max(user_count)-min(user_count) >1000 then 1 else 0 end as threshold
#
# from data
#   ;;
# }

# view: pdt_create_syntax_check{
#   derived_table: {
#     sql:select age, count(*) from public.users group by 1;;
#     persist_for: "10000 minutes"
#     distribution: "all"
#     indexes: ["age"]
#   }
#   dimension: age {}
# }
# explore: pdt_create_syntax_check {}


view: manually_update_trigger {
  derived_table: {
    create_process: {
      sql_step:
        update profservices_scratch.aaa_trigger_max
        set trigger_value = trigger_value +
          case when
          /*custom trigger logic*/
            (select count(*) from public.users) > 10000
          /*end custom trigger logic*/
          then 1 else 0 end;;
      sql_step:
        /*not actually using this...*/
        CREATE TABLE ${SQL_TABLE_NAME} as select * from profservices_scratch.aaa_trigger_max;;
    }
#   sql_trigger_value: select now() ;;#run the update query every 5 minutes
    sql_trigger_value:select datediff(minute,'2019-01-01',GETDATE())/10;;
  }
  dimension: trigger_value {}
}

explore: manually_update_trigger {}

datagroup: alert_testing_manual_trigger_checker {
  sql_trigger: select trigger_value from  profservices_scratch.aaa_trigger_max;;
}

view: view_triggered_by_custom_trigger {
  derived_table: {
    sql:select GETDATE(),age,count(*) as the_count from public.users group by 1,2;;
    datagroup_trigger: alert_testing_manual_trigger_checker
    distribution_style: all
    indexes: ["age"]
  }
  dimension: age {type:number}
  dimension: the_count {type:number}
  measure: total_count {type:sum sql:${the_count};;}
}

explore: view_triggered_by_custom_trigger {}
