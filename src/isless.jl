import Base: isless
Base.isless(::TagChange, ::FolderChange) = false
Base.isless(::FolderChange, ::TagChange) = true
Base.isless(a::FolderChange, b::FolderChange) =
    Base.isless(a.from_folder, b.from_folder) ||
    (isequal(a.from_folder, b.from_folder) && Base.isless(a.to_folder, b.to_folder))

Base.isequal(x::TagChange, y::TagChange) =
    x.tag == y.tag && x.prefix == y.prefix

Base.isless(x::TagChange, y::TagChange) =
    Base.isless(x.prefix, y.prefix) || (isequal(x.prefix, y.prefix)  && Base.isless(x.tag, y.tag))


Base.isless(x::NotmuchLeaf{A}, y::NotmuchLeaf{B}) where {A,B} =
    Base.isless(A, B) || (isequal(A, B)  && Base.isless(x.value, y.value))
