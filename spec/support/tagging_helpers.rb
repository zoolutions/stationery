# frozen_string_literal: true

# Reads a tagged PDF's structure tree back as nested arrays.
module TaggingHelpers
  def catalog_of(pdf)
    objects = reader_for(pdf).objects
    objects.deref(objects.trailer[:Root])
  end

  # [[type, alt, [kid, …]], …] from the Document element down; a kid is a
  # nested element or [page index, MCID] for marked content.
  def struct_tree(pdf)
    objects = reader_for(pdf).objects
    root = objects.deref(catalog_of(pdf)[:StructTreeRoot])
    Array(objects.deref(root[:K])).map { |ref| struct_element(objects, objects.deref(ref)) }
  end

  def struct_element(objects, elem)
    page = elem[:Pg]
    kids = Array(objects.deref(elem[:K])).map do |kid|
      case kid
      when Integer then [objects.page_references.index(page), kid]
      when Hash then [objects.page_references.index(kid[:Pg]), kid[:MCID]]
      else struct_element(objects, objects.deref(kid))
      end
    end
    [elem[:S], elem[:Alt], kids]
  end

  # The structure types in reading order, nested, without marked content.
  def struct_types(pdf) = struct_tree(pdf).map { |elem| types_of(elem) }

  def types_of((type, _alt, kids))
    nested = kids.select { |kid| kid.first.is_a?(Symbol) }
    nested.empty? ? type : [type, nested.map { |kid| types_of(kid) }]
  end

  # { StructParents key => [element types by MCID] } from the parent tree.
  def parent_tree(pdf)
    objects = reader_for(pdf).objects
    nums = objects.deref(objects.deref(catalog_of(pdf)[:StructTreeRoot])[:ParentTree])[:Nums]
    nums.each_slice(2).to_h do |key, value|
      [key, Array(objects.deref(value)).map { |ref| objects.deref(ref)[:S] }]
    end
  end
end

RSpec.configure { |config| config.include TaggingHelpers }
