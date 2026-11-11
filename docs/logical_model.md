\# Logical relational model



Notation: \*\*primary key\*\*, `->` foreign key. Every table is in 3NF.



\- data\_source(\*\*source\_id\*\*, name, organization, url, license, retrieved\_on)

\- import\_batch(\*\*batch\_id\*\*, source\_id -> data\_source, started\_at, rows\_read, rows\_loaded, rows\_rejected)

\- who\_region(\*\*who\_region\_id\*\*, code, name)

\- wb\_region(\*\*wb\_region\_id\*\*, name)

\- income\_group(\*\*income\_group\_id\*\*, name)

\- country(\*\*country\_id\*\*, iso3, name, who\_region\_id -> who\_region, wb\_region\_id -> wb\_region, income\_group\_id -> income\_group)

\- sex(\*\*sex\_id\*\*, code, label)

\- indicator(\*\*indicator\_id\*\*, code, name, unit, source\_id -> data\_source)

\- observation(\*\*observation\_id\*\*, country\_id -> country, indicator\_id -> indicator, sex\_id -> sex, year, value, ci\_low, ci\_high, batch\_id -> import\_batch)

\- audit\_log(\*\*audit\_id\*\*, table\_name, operation, record\_id, old\_value, new\_value, changed\_at, changed\_by)



\## Relationships

\- One-to-many: who\_region, wb\_region and income\_group -> country; country, indicator and sex -> observation;

&#x20; data\_source -> indicator; data\_source -> import\_batch; import\_batch -> observation.

\- Many-to-many: country <-> indicator, resolved by observation (with sex and year as extra attributes).

\- Optional: the three country foreign keys, ci\_low, ci\_high, batch\_id. Mandatory: all other columns.



\## Design decisions

\- One generic `observation` table instead of one table per indicator, so a new indicator needs only a new row in `indicator`. The wide format is rebuilt with the view `v\_country\_year`.

\- WHO regions and World Bank regions are kept in separate tables, because the two organizations group countries differently.

\- Country attributes are stored once in `country`, so names and regions are not repeated on 30,912 rows.

\- `import\_batch` and `audit\_log` are not part of the source data. They were added to track the import and changes.

