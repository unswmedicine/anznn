# ANZNN - Australian & New Zealand Neonatal Network
# Copyright (C) 2017 Intersect Australia Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

module Admin::UsersHelper

  def hospital_filter_options(current_selection)
    hospitals = grouped_options_for_select(Hospital.hospitals_by_state, current_selection)
    others = if current_selection == "None"
               '<option value="">ANY</option><option value="None" selected>None</option>'
             else
               '<option value="">ANY</option><option value="None">None</option>'
             end
    (others + hospitals).html_safe
  end
end
