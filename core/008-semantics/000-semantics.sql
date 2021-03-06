/*******************************************************************************
 * Semantics
 * A space to decorate the db schema with meaning
 *
 * Created by Aquameta Labs, an open source company in Portland Oregon, USA.
 * Company: http://aquameta.com/
 * Project: http://blog.aquameta.com/
 ******************************************************************************/
begin;

create schema semantics;
set search_path=semantics;

create table semantics.relation_purpose (
    id uuid primary key default public.uuid_generate_v4(),
    purpose text not null
);

create table semantics.relation (
    id meta.relation_id,
    purpose_id uuid references semantics.relation_purpose(id),
    widget_id uuid references widget.widget(id) not null,
    priority integer not null default 0
);

insert into semantics.relation_purpose (purpose) values 
    ('overview'),
    ('list_view'),
    ('list_item'),
    ('row_detail'),
    ('new_row'),
    ('grid_view'),
    ('grid_row');


create table semantics.column_purpose (
    id uuid primary key default public.uuid_generate_v4(),
    purpose text not null
);

create table semantics."type" (
    id meta.type_id,
    purpose_id uuid references semantics.column_purpose(id) not null,
    widget_id uuid references widget.widget(id) not null,
    priority integer not null default 0
);

create table semantics."column" (
    id meta.column_id,
    purpose_id uuid references semantics.column_purpose(id) not null,
    widget_id uuid references widget.widget(id) not null,
    priority integer not null default 0
);


insert into semantics.column_purpose (purpose) values
    ('form_field'),
    ('form_label'),
    ('form_display'),
    ('form_edit'),
    ('grid_label'),
    ('grid_display'),
    ('grid_edit');


create table semantics.foreign_key (
    id meta.foreign_key_id primary key,
    inline boolean default false
);


create or replace function semantics.relation_widget (
    relation_id meta.relation_id,
    widget_purpose text,
    default_bundle text
) returns setof widget.widget as
$$
begin
    return query execute 'select ' || (
        select string_agg(name, ', ')
        from meta.column
        where schema_name='widget'
            and relation_name='widget' ) ||
    ' from (
        select w.*, r.priority
        from semantics.relation r
            join semantics.relation_purpose rp on rp.id = r.purpose_id
            join widget.widget w on w.id = r.widget_id
        where r.id = meta.relation_id(' || quote_literal((relation_id::meta.schema_id).name) || ', ' || quote_literal((relation_id).name) || ')
            and rp.purpose = ' || quote_literal(widget_purpose) ||
        'union
        select *, -1 as priority from widget.bundled_widget(' || quote_literal(default_bundle) || ', ' || quote_literal(widget_purpose) || ')
    ) a
    order by priority desc
    limit 1';
end;
$$ language plpgsql;


create or replace function semantics.column_widget (
    column_id meta.column_id,
    widget_purpose text,
    default_bundle text
) returns setof widget.widget as
$$
begin
    return query execute 'select ' || (
        select string_agg(name, ', ')
        from meta.column
        where schema_name='widget'
            and relation_name='widget' ) ||
    ' from (
        select w.*, c.priority, ''c'' as type
        from semantics.column c
            join semantics.column_purpose cp on cp.id = c.purpose_id
            join widget.widget w on w.id = c.widget_id
        where c.id = meta.column_id(' || quote_literal((column_id::meta.schema_id).name) || ', ' ||
                                         quote_literal((column_id::meta.relation_id).name) || ', ' ||
                                         quote_literal((column_id).name) || ')
            and cp.purpose = ' || quote_literal(widget_purpose) ||
        ' union
        select w.*, t.priority, ''t'' as type
        from semantics.type t
            join semantics.column_purpose cp on cp.id = t.purpose_id
            join widget.widget w on w.id = t.widget_id
            join meta.column mc on mc.type_id = t.id
        where mc.id = meta.column_id(' || quote_literal((column_id::meta.schema_id).name) || ', ' ||
                                         quote_literal((column_id::meta.relation_id).name) || ', ' ||
                                         quote_literal((column_id).name) || ')
            and cp.purpose = ' || quote_literal(widget_purpose) ||
        ' union
        select *, -1 as priority, ''z'' as type
        from widget.bundled_widget(' || quote_literal(default_bundle) || ', ' || quote_literal(widget_purpose) || ')
    ) a
    order by type asc, priority desc
    limit 1';
end;
$$ language plpgsql;


commit;

